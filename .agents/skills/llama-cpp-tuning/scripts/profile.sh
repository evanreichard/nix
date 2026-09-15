#!/usr/bin/env bash
# Sample CPU, GPU, memory and I/O utilization during decode, then map saturation to useful flags.

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

rexec "curl -sS http://127.0.0.1:${LLAMA_PORT}/v1/chat/completions -H 'Content-Type: application/json' --data-binary @${PAYLOAD} > /tmp/llama-tune-profile-out.json 2>&1 &" >/dev/null
sleep 3

cpu=$(rexec "vmstat 1 ${SECONDS_TO_SAMPLE}" | tail -n +4 | awk '
  {us+=$13; sy+=$14; id+=$15; wa+=$16; n++}
  END {if(n>0) printf "%.0f %.0f %.0f %.0f", us/n, sy/n, id/n, wa/n}')
read -r US SY ID WA <<< "$cpu"
gpu=$(rexec "nvidia-smi --query-gpu=index,utilization.gpu,utilization.memory,memory.used,memory.total --format=csv,noheader,nounits")
ncpu=$(rexec "nproc")

tg=""
for _ in $(seq 1 20); do
  tg=$(rexec "grep -o '\"predicted_per_second\":[0-9.]*' /tmp/llama-tune-profile-out.json 2>/dev/null | tail -1 | cut -d: -f2")
  [ -n "$tg" ] && break
  sleep 2
done

echo "# target=$(target_label)"
echo "CPU (${ncpu} logical): busy=${US}% sys=${SY}% idle=${ID}% iowait=${WA}%"
echo "  -> ~$(awk -v u="$US" -v n="$ncpu" 'BEGIN{printf "%.1f", u*n/100}') cores saturated"
echo "GPU (index util% memutil% usedMiB totalMiB):"
echo "$gpu" | sed 's/^/  /'
if [ -n "$tg" ]; then echo "decode: ${tg} tok/s"; else echo "decode: (request still running)"; fi

cat <<'EOF'

Classification
  GPU util >80%                    -> GPU compute: smaller quant, `-fa`, batch size.
  GPU low, CPU busy:
    RAM traffic near ceiling       -> RAM bandwidth: smaller quant, fewer CPU layers.
    RAM traffic below ceiling      -> CPU compute: cheaper quant, fewer CPU layers.
  iowait >5%                       -> disk streaming: `-lm none` or `--mlock`.
  Multiple GPUs underused          -> device hops: fewer devices or adjust `-ts`.
  Nothing saturated                -> batch or synchronization overhead.

CPU-resident weight traffic
  bytes/token ~= active_params * (cpu_layers / total_layers) * bytes_per_weight
  achieved    = bytes/token * decode_tok_s
EOF
