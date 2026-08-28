#!/usr/bin/env bash
# Sweep placement candidates with llama-fit-params and report which ones fit VRAM.
#
# Usage:
#   fit.sh --model PATH --ctx N [--host H] [--dev CUDA0,CUDA1] [--ncmoe 20,22,24]
#          [--vram 11264] [--headroom 600] [-- <extra llama-fit-params args>]
#
# Prints estimated per-device totals (model + context + compute) and a verdict.
# The estimator runs in seconds and loads no weights, so sweep freely.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

MODEL=""; CTX=""; DEV=""; NCMOE=""; VRAM=""; HEADROOM=600; EXTRA=()
parse_common_args "$@"
set -- "${REST[@]}"
while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --ctx) CTX="$2"; shift 2 ;;
    --dev) DEV="$2"; shift 2 ;;
    --ncmoe) NCMOE="$2"; shift 2 ;;
    --vram) VRAM="$2"; shift 2 ;;
    --headroom) HEADROOM="$2"; shift 2 ;;
    --) shift; EXTRA=("$@"); break ;;
    *) die "unknown arg: $1" ;;
  esac
done

[ -n "$MODEL" ] || die "--model is required"
[ -n "$CTX" ] || die "--ctx is required"

# Discover the smallest target GPU when no budget was supplied.
if [ -z "$VRAM" ]; then
  VRAM=$(rexec "nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits" | sort -n | head -1)
  echo "# VRAM budget not given; using smallest GPU: ${VRAM} MiB"
fi

echo "# target=$(target_label) model=$(basename "$MODEL") ctx=${CTX} budget=${VRAM} MiB headroom=${HEADROOM} MiB"
printf '%-8s %-8s %10s %10s %10s %10s  %s\n' ncmoe device model ctx compute total verdict

sweep="${NCMOE:-none}"
IFS=',' read -ra CANDIDATES <<< "$sweep"

for n in "${CANDIDATES[@]}"; do
  args="-m $MODEL -c $CTX -ngl all -fit off -fitp on"
  [ -n "$DEV" ] && args="$args -dev $DEV"
  [ "$n" != "none" ] && args="$args -ncmoe $n"
  [ ${#EXTRA[@]} -gt 0 ] && args="$args ${EXTRA[*]}"

  rexec "$LLAMA_FIT_BIN $args 2>/dev/null" | grep -E '^(CUDA|ROCm|Vulkan|SYCL|Metal|Host)' | while read -r dev a b c; do
    total=$(( a + b + c ))
    verdict=""
    if [ "$dev" != "Host" ]; then
      if [ "$total" -gt "$VRAM" ]; then
        verdict="OVER by $(( total - VRAM )) MiB"
      elif [ "$total" -gt $(( VRAM - HEADROOM )) ]; then
        verdict="TIGHT ($(( VRAM - total )) MiB free)"
      else
        verdict="fits ($(( VRAM - total )) MiB free)"
      fi
    fi
    printf '%-8s %-8s %10s %10s %10s %10s  %s\n' "$n" "$dev" "$a" "$b" "$c" "$total" "$verdict"
  done
done

cat <<'EOF'

# Estimates run low. Observed gaps: ~60-130 MiB (dense/k-quant) up to ~800 MiB
# (MoE with a speculative draft context). Always confirm with nvidia-smi after
# the server loads, and keep >=500 MiB free so cuBLAS can allocate its workspace.
EOF
