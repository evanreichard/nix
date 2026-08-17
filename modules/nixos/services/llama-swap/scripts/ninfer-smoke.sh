#!/usr/bin/env bash
# Start NInfer at a given dtype/capacity, run one generation, report the KV ledger
# and request timings, then stop. Confirms a capacity both fits and serves.
#
# Usage: ninfer-smoke.sh <bf16|int8|rk8v4> <tokens> [extra ninfer-serve flags...]
#   NINFER_SERVE  path to ninfer-serve
#   NINFER_MODEL  path to .ninfer artifact
set -uo pipefail

BIN="${NINFER_SERVE:-$(command -v ninfer-serve || true)}"
MODEL="${NINFER_MODEL:-/mnt/ssd/Ninfer/Models/qwen3_8_27b.ninfer}"
PORT="${NINFER_PORT:-8099}"

if [ ! -x "$BIN" ]; then
  echo "ERROR: set NINFER_SERVE to a ninfer-serve binary." >&2
  exit 1
fi

dtype="$1"
tokens="$2"
shift 2
log="$(mktemp)"

CUDA_VISIBLE_DEVICES=0 CUDA_DEVICE_ORDER=PCI_BUS_ID \
"$BIN" "$MODEL" \
  --host 127.0.0.1 --port "$PORT" \
  --model-id smoke \
  --max-context "$tokens" --kv-capacity "$tokens" \
  --max-concurrency 1 --max-pending-requests 16 \
  --prefill-chunk 1024 --kv-dtype "$dtype" \
  --spec mtp --draft-tokens 3 --lm-head-draft \
  --preserve-thinking --cors "$@" >"$log" 2>&1 &
pid=$!

for _ in $(seq 120); do
  grep -q "listening on" "$log" && break
  kill -0 "$pid" 2>/dev/null || { echo "server exited"; tail -3 "$log"; rm -f "$log"; exit 1; }
  sleep 1
done

echo "--- VRAM after load ---"
nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader -i 0

echo "--- generation ---"
curl -s --max-time 300 "localhost:${PORT}/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d '{"model":"smoke","messages":[{"role":"user","content":"In one sentence, what is speculative decoding?"}],"reasoning_effort":"low","max_tokens":256}' |
  jq -r '.choices[0].message.content, (.usage | "usage: prompt=\(.prompt_tokens) completion=\(.completion_tokens)")'

echo "--- server ledger ---"
grep -iE "KV capacity|done finish" "$log" | tail -4

kill "$pid" 2>/dev/null
wait "$pid" 2>/dev/null
rm -f "$log"
