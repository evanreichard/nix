#!/usr/bin/env bash
# Shared helpers for inference benchmark scripts. Source, don't execute.

set -euo pipefail

INFER_HOST="${INFER_HOST:-}"
INFER_PORT="${INFER_PORT:-8082}"
LLAMA_SERVER_BIN="${LLAMA_SERVER_BIN:-llama-server}"
LLAMA_FIT_BIN="${LLAMA_FIT_BIN:-llama-fit-params}"

# Consume --host/--port/--server-bin/--fit-bin from "$@"; leave the rest in REST[].
parse_common_args() {
  REST=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --host) INFER_HOST="$2"; shift 2 ;;
      --port) INFER_PORT="$2"; shift 2 ;;
      --server-bin) LLAMA_SERVER_BIN="$2"; shift 2 ;;
      --fit-bin) LLAMA_FIT_BIN="$2"; shift 2 ;;
      *) REST+=("$1"); shift ;;
    esac
  done
}

# Run a shell string on the target (remote when --host given, else local).
rexec() {
  if [ -n "$INFER_HOST" ]; then
    ssh -o BatchMode=yes "$INFER_HOST" "$1"
  else
    bash -c "$1"
  fi
}

# Pipe stdin into a file on the target.
rput() {
  if [ -n "$INFER_HOST" ]; then
    ssh -o BatchMode=yes "$INFER_HOST" "cat > $1"
  else
    cat > "$1"
  fi
}

target_label() {
  if [ -n "$INFER_HOST" ]; then echo "$INFER_HOST"; else echo "localhost"; fi
}

die() { echo "error: $*" >&2; exit 1; }

# Pull one numeric field out of a llama.cpp /v1/chat/completions response.
json_num() {
  grep -o "\"$1\":[0-9.]*" | head -1 | cut -d: -f2
}

# Echo "prompt_tok/s decode_tok/s output_tokens" for either backend: llama.cpp
# reports *_per_second at the top level, vLLM reports usage plus a metrics object
# under --enable-per-request-metrics and needs jq to read it. Empty fields mean
# the body carried no timing at all.
metrics_of() {
  local body="$1"
  if printf '%s' "$body" | jq -e '.metrics' >/dev/null 2>&1; then
    printf '%s %s %s' \
      "$(printf '%s' "$body" | jq -r '(.usage.prompt_tokens / (.metrics.time_to_first_token_ms / 1000)) | floor')" \
      "$(printf '%s' "$body" | jq -r '.metrics.tokens_per_second | floor')" \
      "$(printf '%s' "$body" | jq -r '.usage.completion_tokens')"
  else
    printf '%s %s %s' \
      "$(printf '%s' "$body" | json_num prompt_per_second)" \
      "$(printf '%s' "$body" | json_num predicted_per_second)" \
      "$(printf '%s' "$body" | json_num predicted_n)"
  fi
}
