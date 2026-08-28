#!/usr/bin/env bash
# Sample CPU, GPU and I/O while the server decodes, then classify the bottleneck.
#
# Usage:
#   profile.sh [--host H] [--port 8082] [--tokens 400] [--seconds 12]
#
# Run this BEFORE turning knobs. Which resource is saturated determines which
# levers can possibly help; guessing wastes reload cycles.
#
# Keep --tokens large enough that generation outlasts --seconds; if the request
# finishes mid-window the averages dilute toward idle and understate saturation.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

TOKENS=400; SECONDS_TO_SAMPLE=12
parse_common_args "$@"
set -- "${REST[@]}"
while [ $# -gt 0 ]; do
  case "$1" in
    --tokens) TOKENS="$2"; shift 2 ;;
    --seconds) SECONDS_TO_SAMPLE="$2"; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done

PAYLOAD="/tmp/llama-tune-profile-${LLAMA_PORT}.json"
printf '{"model":"profile","max_tokens":%s,"temperature":0.6,"messages":[{"role":"user","content":"Write a detailed technical explanation of write-ahead logging, checkpointing, and crash recovery in database engines."}]}' \
  "$TOKENS" | rput "$PAYLOAD"

echo "# target=$(target_label) sampling ${SECONDS_TO_SAMPLE}s during decode"

# Kick off generation on the target, then sample while it runs.
rexec "curl -sS http://127.0.0.1:${LLAMA_PORT}/v1/chat/completions -H 'Content-Type: application/json' --data-binary @${PAYLOAD} > /tmp/llama-tune-profile-out.json 2>&1 &" >/dev/null
sleep 3

cpu=$(rexec "vmstat 1 ${SECONDS_TO_SAMPLE}" | tail -n +4 | awk '
  {us+=$13; sy+=$14; id+=$15; wa+=$16; n++}
  END {if(n>0) printf "%.0f %.0f %.0f %.0f", us/n, sy/n, id/n, wa/n}')
read -r US SY ID WA <<< "$cpu"

gpu=$(rexec "nvidia-smi --query-gpu=index,utilization.gpu,utilization.memory,memory.used,memory.total,clocks.sm,clocks.max.sm,temperature.gpu,power.draw --format=csv,noheader,nounits")
# Throttling is invisible in utilization figures: a clamped GPU still reports 99%.
throttle=$(rexec "nvidia-smi -i 0 -q -d PERFORMANCE | grep -E 'SW Power Cap|HW Thermal|SW Thermal|HW Power Brake' | sed 's/^ *//'")
ncpu=$(rexec "nproc")
# Sampling usually ends before generation does; give the request a moment to land.
tg=""
for _ in $(seq 1 20); do
  tg=$(rexec "grep -o '\"predicted_per_second\":[0-9.]*' /tmp/llama-tune-profile-out.json 2>/dev/null | tail -1 | cut -d: -f2")
  [ -n "$tg" ] && break
  sleep 2
done

echo
echo "CPU (${ncpu} logical): busy=${US}% sys=${SY}% idle=${ID}% iowait=${WA}%"
echo "  -> ~$(awk -v u="$US" -v n="$ncpu" 'BEGIN{printf "%.1f", u*n/100}') cores saturated"
echo "GPU (index util% memutil% usedMiB totalMiB smMHz maxMHz tempC W):"
echo "$gpu" | sed 's/^/  /'
echo "Clock event reasons (GPU0):"
echo "$throttle" | sed 's/^/  /'
if [ -n "$tg" ]; then echo "decode: ${tg} tok/s"; else echo "decode: (request still running)"; fi

cat <<'EOF'

Classification
  GPU util >80%                    -> GPU compute bound. Weights are placed well;
                                      gains come from quant/batch, not placement.
  iowait >5%                       -> reading weights from disk. Add `-lm none`
                                      (or --mlock) so offloaded tensors live in RAM.
  CPU cores pegged, GPU low        -> CPU bound. Compute the RAM bandwidth below to
                                      split compute-bound from bandwidth-bound.
  Nothing saturated                -> latency/sync bound: per-layer device hops,
                                      tiny batches, or thermal/clock throttling.

RAM bandwidth check (CPU-offloaded MoE)
  bytes/token ~= active_params * (cpu_layers / total_layers) * bytes_per_weight
  achieved    =  bytes/token * decode_tok_s
  Compare against a measured ceiling (~45 GB/s for dual-channel DDR4-3200).
    achieved well under ceiling -> CPU compute bound: switch CPU-resident weights
      to a cheaper-to-decode quant (k-quant over IQ), even a physically larger one.
    achieved near ceiling       -> bandwidth bound: cut bytes/token via a smaller
      quant or by moving layers back onto the GPU.
EOF
