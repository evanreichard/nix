#!/usr/bin/env bash
# Start/stop a llama-server for benchmarking, on a remote host or locally.
#
# Usage:
#   serve.sh start --model PATH [--host H] [--port 8082] [--visible-devices 1]
#                  [--timeout 300] [-- <llama-server flags>]
#   serve.sh stop  [--host H] [--port 8082]
#   serve.sh status [--host H] [--port 8082]
#
# start blocks until the server reports it is listening, then prints VRAM use.
# Cold `-lm none` loads read the whole file into RAM and can take minutes.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

CMD="${1:-}"; shift || true
[ -n "$CMD" ] || die "usage: serve.sh {start|stop|status} [...]"

MODEL=""; VISIBLE=""; TIMEOUT=300; FLAGS=()
parse_common_args "$@"
set -- "${REST[@]}"
while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --visible-devices) VISIBLE="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --) shift; FLAGS=("$@"); break ;;
    *) die "unknown arg: $1" ;;
  esac
done

LOG="/tmp/llama-tune-${LLAMA_PORT}.log"
PROC_PAT="[l]lama-server.*--port ${LLAMA_PORT}"

stop_server() {
  # PROC_PAT brackets the first letter so the pattern never matches the ssh
  # wrapper that carries it, which would otherwise self-match (and self-kill).
  rexec "pkill -f '${PROC_PAT}' 2>/dev/null; true"
  for _ in $(seq 1 30); do
    if ! rexec "pgrep -f '${PROC_PAT}' >/dev/null 2>&1"; then break; fi
    sleep 1
  done
  sleep 2
  echo "stopped (port ${LLAMA_PORT})"
  rexec "nvidia-smi --query-gpu=index,memory.used --format=csv,noheader" 2>/dev/null || true
}

case "$CMD" in
  stop) stop_server ;;

  status)
    rexec "pgrep -af '${PROC_PAT}' | cat"
    rexec "nvidia-smi --query-gpu=index,memory.used,utilization.gpu --format=csv,noheader"
    ;;

  start)
    [ -n "$MODEL" ] || die "--model is required"
    stop_server >/dev/null 2>&1 || true

    # `env` is required: nohup would treat a bare VAR=value as the command name.
    prefix=""
    [ -n "$VISIBLE" ] && prefix="env CUDA_VISIBLE_DEVICES=${VISIBLE} "
    cmdline="${prefix}${LLAMA_SERVER_BIN} --host 127.0.0.1 --port ${LLAMA_PORT} -m ${MODEL} ${FLAGS[*]} --perf"

    echo "# target=$(target_label)"
    echo "# ${cmdline}"
    rexec "nohup ${cmdline} > ${LOG} 2>&1 & echo started"

    # One round trip per poll: report ready / dead / still-loading in a single word.
    for _ in $(seq 1 "$TIMEOUT"); do
      state=$(rexec "if grep -q 'listening on http' ${LOG} 2>/dev/null; then echo ready; elif pgrep -f '${PROC_PAT}' >/dev/null 2>&1; then echo loading; else echo dead; fi")
      case "$state" in
        ready)
          echo "ready"
          rexec "nvidia-smi --query-gpu=index,memory.used --format=csv,noheader"
          rexec "free -h | sed -n 2p"
          exit 0
          ;;
        dead)
          echo "server exited during load; tail of ${LOG}:" >&2
          rexec "tail -20 ${LOG}" >&2
          exit 1
          ;;
      esac
      sleep 2
    done
    die "timed out after ${TIMEOUT} polls; inspect ${LOG} on $(target_label)"
    ;;

  *) die "unknown command: $CMD" ;;
esac
