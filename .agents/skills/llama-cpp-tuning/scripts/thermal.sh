#!/usr/bin/env bash
# Verify the GPU sustains clocks under repeated load before trusting any A/B result.
#
# Usage:
#   thermal.sh [--host H] [--port 8082] [--rounds 5] [--tokens 512]
#
# Runs N back-to-back generations against a loaded server and reports decode rate
# alongside SM clock and throttle state for each. A card that clamps mid-series
# invalidates every benchmark taken across it, because each configuration then
# gets measured at a different point in the heat cycle.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

ROUNDS=5; TOKENS=512
parse_common_args "$@"
set -- "${REST[@]}"
while [ $# -gt 0 ]; do
  case "$1" in
    --rounds) ROUNDS="$2"; shift 2 ;;
    --tokens) TOKENS="$2"; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done

PAYLOAD="/tmp/llama-tune-thermal-${LLAMA_PORT}.json"

# Distinct prompts each round: identical prompts hit the prefix cache and, with
# n-gram speculation, warm a draft cache that inflates later rounds.
TOPICS=(
  "how B-trees reduce disk I/O for range queries"
  "how LSM trees handle compaction and read amplification"
  "how two-phase commit handles coordinator failure"
  "how consistent hashing distributes keys under node churn"
  "how vectorized execution improves CPU cache use"
  "how MVCC provides snapshot isolation"
  "how Raft performs leader election and log compaction"
  "how query planners estimate join cardinality"
)

echo "# target=$(target_label) rounds=${ROUNDS} tokens=${TOKENS}"
printf '%-7s %10s %9s %8s %7s  %s\n' round tok/s smMHz tempC watt throttle

for i in $(seq 1 "$ROUNDS"); do
  topic="${TOPICS[$(( (i - 1) % ${#TOPICS[@]} ))]}"
  printf '{"model":"thermal","max_tokens":%s,"temperature":0.6,"messages":[{"role":"user","content":"Write a detailed 400-word technical explanation of %s."}]}' \
    "$TOKENS" "$topic" | rput "$PAYLOAD"

  resp=$(rexec "curl -sS http://127.0.0.1:${LLAMA_PORT}/v1/chat/completions -H 'Content-Type: application/json' --data-binary @${PAYLOAD}")
  tg=$(printf '%s' "$resp" | json_num predicted_per_second)

  read -r SM TEMP W <<< "$(rexec "nvidia-smi -i 0 --query-gpu=clocks.sm,temperature.gpu,power.draw --format=csv,noheader,nounits" | tr -d ',')"
  reasons=$(rexec "nvidia-smi -i 0 -q -d PERFORMANCE | grep -E 'SW Thermal|HW Thermal|SW Power Cap|HW Power Brake' | grep -c Active" || true)
  active=$(rexec "nvidia-smi -i 0 -q -d PERFORMANCE | grep -E 'SW Thermal Slowdown|HW Thermal Slowdown|SW Power Cap|HW Power Brake' | grep Active | sed 's/ *:.*//; s/^ *//' | tr '\n' ',' " || true)

  printf '%-7s %10.2f %9s %8s %7s  %s\n' "$i" "${tg:-0}" "$SM" "$TEMP" "$W" "${active:-none}"
done

cat <<'EOF'

# Reading the table
#   Stable tok/s and stable SM clock  -> safe to A/B configurations.
#   tok/s falling with SM clock       -> thermally limited. Fix cooling first;
#                                        flag comparisons taken across the decay
#                                        measure heat, not the flags.
#   Clock down while the core stays cool and power sits under the cap
#                                     -> the limiting sensor is not the core.
#                                        Suspect memory/VRM heat or airflow.
#
# Multi-fan cards: `nvidia-smi --query-gpu=fan.speed` and nvtop report FAN 0 ONLY.
# A dead fan 0 shows 0% while other fans work normally. Read every fan through
# NVML (nvmlDeviceGetNumFans + nvmlDeviceGetFanSpeed_v2) before concluding the
# fans are idle. Consumer boards frequently do not expose memory temperature at
# all (NVML_FI_DEV_MEMORY_TEMP returns NOT_SUPPORTED), so memory overheating can
# only be inferred, never read.
EOF
