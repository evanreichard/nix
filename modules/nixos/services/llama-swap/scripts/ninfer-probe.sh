#!/usr/bin/env bash
# Probe an NInfer KV capacity on the local GPU.
#
# Prints "FIT <required> <available>" when the reservation is rejected, or
# "OK ... free_mib=N" when the server reaches its listening state. Reservation is
# linear in capacity, so two FIT results at different capacities determine the
# whole curve - see README.md.
#
# Usage: ninfer-probe.sh <bf16|int8|rk8v4> <tokens> [extra ninfer-serve flags...]
#   NINFER_SERVE  path to ninfer-serve   (default: nix build /etc/nixos#ninfer-3090)
#   NINFER_MODEL  path to .ninfer artifact
#
# Extra flags matter: --vision and --max-concurrency change the fixed reservation,
# so probe with the same flags the target profile will run.
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

start=$(date +%s)
CUDA_VISIBLE_DEVICES=0 CUDA_DEVICE_ORDER=PCI_BUS_ID \
timeout 300 "$BIN" "$MODEL" \
  --host 127.0.0.1 --port "$PORT" \
  --max-context "$tokens" --kv-capacity "$tokens" \
  --max-concurrency 1 --max-pending-requests 16 \
  --prefill-chunk 1024 --kv-dtype "$dtype" \
  --spec mtp --draft-tokens 3 --lm-head-draft \
  --preserve-thinking --cors "$@" >"$log" 2>&1 &
pid=$!

while kill -0 "$pid" 2>/dev/null; do
  if grep -q "listening on" "$log"; then
    free=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits -i 0)
    echo "OK ${dtype} ${tokens} elapsed=$(( $(date +%s) - start ))s free_mib=${free}"
    grep -o "KV capacity.*" "$log" | tail -1
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    rm -f "$log"
    exit 0
  fi
  sleep 1
done
wait "$pid" 2>/dev/null

if grep -q "requires" "$log"; then
  read -r req avail < <(grep -o 'requires [0-9]* bytes, but only [0-9]*' "$log" |
    sed 's/requires \([0-9]*\) bytes, but only \([0-9]*\)/\1 \2/')
  echo "FIT ${dtype} ${tokens} required=${req} available=${avail}"
else
  echo "FAIL ${dtype} ${tokens}"
  tail -5 "$log"
fi
rm -f "$log"
