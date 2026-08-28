#!/usr/bin/env bash
# Benchmark a running llama-server across the workload shapes that stress
# different bottlenecks. Reports prompt (pp) and generation (tg) tok/s.
#
# Usage:
#   bench.sh [--host H] [--port 8082] [--cases short,copy,prefill,deep]
#            [--tokens 384] [--depth 40000] [--repeat 2]
#
# Cases:
#   short   - 400-word prose. Baseline single-stream decode.
#   copy    - code rewrite whose output largely echoes the prompt. The only
#             case where speculative decoding can win; low n-gram hit rate
#             elsewhere makes prose useless for judging it.
#   prefill - ~10K-token prompt, 128 output. Isolates prefill throughput.
#   deep    - fills KV to --depth before decoding. Decode slows markedly with
#             context depth; a short-prompt number alone is misleading.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

CASES="short,copy,prefill,deep"; TOKENS=384; DEPTH=40000; REPEAT=2
parse_common_args "$@"
set -- "${REST[@]}"
while [ $# -gt 0 ]; do
  case "$1" in
    --cases) CASES="$2"; shift 2 ;;
    --tokens) TOKENS="$2"; shift 2 ;;
    --depth) DEPTH="$2"; shift 2 ;;
    --repeat) REPEAT="$2"; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done

PAYLOAD="/tmp/llama-tune-payload-${LLAMA_PORT}.json"

# Emit a JSON string body (escaped) for a prompt built from a repeated unit.
build_prompt() {
  local kind="$1"
  case "$kind" in
    short) printf 'Write a 400-word explanation of how B-trees reduce disk I/O for range queries. Be technical.' ;;
    copy)
      printf 'Here is a Go function:\\n\\n'
      printf 'func (s *Store) RangeScan(ctx context.Context, lo, hi Key, limit int) ([]Record, error) {\\n'
      printf '    if limit <= 0 { return nil, fmt.Errorf(\\"range scan: limit must be positive\\") }\\n'
      printf '    tx, err := s.db.BeginTx(ctx, &sql.TxOptions{ReadOnly: true})\\n'
      printf '    if err != nil { return nil, fmt.Errorf(\\"range scan: begin tx: %%w\\", err) }\\n'
      printf '    defer tx.Rollback()\\n'
      printf '    rows, err := tx.QueryContext(ctx, rangeScanQuery, lo.Bytes(), hi.Bytes(), limit)\\n'
      printf '    if err != nil { return nil, fmt.Errorf(\\"range scan: query: %%w\\", err) }\\n'
      printf '    defer rows.Close()\\n'
      printf '    out := make([]Record, 0, limit)\\n'
      printf '    for rows.Next() {\\n'
      printf '        var rec Record\\n'
      printf '        if err := rows.Scan(&rec.Key, &rec.Value, &rec.Version); err != nil { return nil, err }\\n'
      printf '        out = append(out, rec)\\n'
      printf '    }\\n'
      printf '    return out, rows.Err()\\n'
      printf '}\\n\\n'
      printf 'Reproduce this function verbatim, changing only RangeScan to PrefixScan and the error prefix to \\"prefix scan\\". Output only code.'
      ;;
    prefill|deep)
      local words="$2"
      local i=0
      while [ "$i" -lt "$words" ]; do
        printf 'The write-ahead log forces log records to stable storage before dirty data pages are written back, which bounds recovery work after a crash. '
        i=$(( i + 1 ))
      done
      printf '\\n\\nSummarize the above in three sentences.'
      ;;
  esac
}

run_case() {
  local name="$1" prompt="$2" maxtok="$3"
  printf '{"model":"bench","max_tokens":%s,"temperature":0.6,"top_p":0.95,"top_k":20,"min_p":0.0,"messages":[{"role":"user","content":"%s"}]}' \
    "$maxtok" "$prompt" | rput "$PAYLOAD"

  for i in $(seq 1 "$REPEAT"); do
    local resp pp tg n
    resp=$(rexec "curl -sS http://127.0.0.1:${LLAMA_PORT}/v1/chat/completions -H 'Content-Type: application/json' --data-binary @${PAYLOAD}")
    pp=$(printf '%s' "$resp" | json_num prompt_per_second)
    tg=$(printf '%s' "$resp" | json_num predicted_per_second)
    n=$(printf '%s' "$resp" | json_num predicted_n)
    if [ -z "$tg" ]; then
      echo "  ${name} run${i}: no timings — response head: $(printf '%s' "$resp" | head -c 200)"
      continue
    fi
    printf '  %-8s run%-2s pp %8.2f t/s   tg %8.2f t/s   (%s tok)\n' "$name" "$i" "$pp" "$tg" "$n"
  done
}

echo "# target=$(target_label) port=${LLAMA_PORT} repeat=${REPEAT}"
echo "# warmup"
run_case warmup "Say hello." 32 >/dev/null 2>&1 || true

IFS=',' read -ra SELECTED <<< "$CASES"
for c in "${SELECTED[@]}"; do
  case "$c" in
    short)   run_case short   "$(build_prompt short)" "$TOKENS" ;;
    copy)    run_case copy    "$(build_prompt copy)" "$TOKENS" ;;
    prefill) run_case prefill "$(build_prompt prefill 700)" 128 ;;
    deep)    run_case deep    "$(build_prompt deep $(( DEPTH / 22 )))" 128 ;;
    *) die "unknown case: $c" ;;
  esac
done

cat <<'EOF'

# Single short requests vary by +/-25% because reasoning length varies. Trust
# sustained runs (>=384 tokens) and compare like-for-like prompts. Servers with
# n-gram speculation warm a cache across identical repeats, inflating later runs.
EOF
