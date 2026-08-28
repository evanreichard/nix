#!/usr/bin/env bash
# Shared helpers for llama.cpp tuning scripts. Source, don't execute.

set -euo pipefail

LLAMA_HOST="${LLAMA_HOST:-}"
LLAMA_PORT="${LLAMA_PORT:-8082}"
LLAMA_SERVER_BIN="${LLAMA_SERVER_BIN:-llama-server}"
LLAMA_FIT_BIN="${LLAMA_FIT_BIN:-llama-fit-params}"

# Consume --host/--port/--server-bin/--fit-bin from "$@"; leave the rest in REST[].
parse_common_args() {
  REST=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --host) LLAMA_HOST="$2"; shift 2 ;;
      --port) LLAMA_PORT="$2"; shift 2 ;;
      --server-bin) LLAMA_SERVER_BIN="$2"; shift 2 ;;
      --fit-bin) LLAMA_FIT_BIN="$2"; shift 2 ;;
      *) REST+=("$1"); shift ;;
    esac
  done
}

# Run a shell string on the target (remote when --host given, else local).
rexec() {
  if [ -n "$LLAMA_HOST" ]; then
    ssh -o BatchMode=yes "$LLAMA_HOST" "$1"
  else
    bash -c "$1"
  fi
}

# Pipe stdin into a file on the target.
rput() {
  if [ -n "$LLAMA_HOST" ]; then
    ssh -o BatchMode=yes "$LLAMA_HOST" "cat > $1"
  else
    cat > "$1"
  fi
}

target_label() {
  if [ -n "$LLAMA_HOST" ]; then echo "$LLAMA_HOST"; else echo "localhost"; fi
}

die() { echo "error: $*" >&2; exit 1; }

# Pull one numeric field out of a llama.cpp /v1/chat/completions response.
json_num() {
  grep -o "\"$1\":[0-9.]*" | head -1 | cut -d: -f2
}
