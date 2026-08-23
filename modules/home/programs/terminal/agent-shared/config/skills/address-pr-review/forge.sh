#!/usr/bin/env bash
# Forge-agnostic core for the address-pr-review skill. Sourced by review.sh and
# resolve_thread.sh; parses the git remote, picks a provider, and dispatches through
# `forge <op> [args...]`.
#
# Adding a forge means dropping one `forge_<name>.sh` file next to this one. It is sourced
# automatically and must define these six functions:
#
#   <name>_probe            exit 0 if it owns REMOTE_HOST (no output, no side effects)
#   <name>_init             set ME and PR_NUM, validate credentials, err out otherwise
#   <name>_threads          emit unresolved threads, one json object per line, oldest first:
#                             {"key": "...", "path": "...", "line": N,
#                              "comments": [{"id": ..., "login": "...", "body": "..."}]}
#   <name>_react <id>       add a thumbs-up to one comment (best effort, never fatal)
#   <name>_reply <key> <b>  post a reply into the thread
#   <name>_resolve <key>    mark the thread resolved
#
# Thread keys are opaque to the workflow: whatever <name>_threads emits comes back
# unchanged to <name>_reply and <name>_resolve.

err() { echo "error: $1" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || err "'$1' not found"; }

FORGE_DIR=$(dirname "${BASH_SOURCE[0]}")
for _impl in "$FORGE_DIR"/forge_*.sh; do
  # shellcheck source=/dev/null
  source "$_impl"
done
unset _impl

# forge_providers - Provider names, derived from the `<name>_probe` functions the sourced
# implementation files define. `declare -F` rather than `compgen`, which is absent from
# bash builds without programmable completion.
forge_providers() {
  declare -F | sed -n 's/^declare -f \(.*\)_probe$/\1/p' | sort
}

forge() {
  local op="$1"
  shift
  declare -F "${FORGE}_${op}" >/dev/null || err "forge '${FORGE}' does not implement '${op}'"
  "${FORGE}_${op}" "$@"
}

forge_remote_url() {
  local remote
  remote=$(git config --get "branch.$(git branch --show-current).remote" 2>/dev/null) || remote=""
  git remote get-url "${remote:-origin}" 2>/dev/null || err "no git remote '${remote:-origin}'"
}

forge_parse_remote() {
  local url="$1" rest
  case "$url" in
    *://*)
      rest=${url#*://}
      rest=${rest#*@}
      REMOTE_HOST=${rest%%/*}
      REMOTE_PATH=${rest#*/}
      ;;
    *:*)
      rest=${url#*@}
      REMOTE_HOST=${rest%%:*}
      REMOTE_PATH=${rest#*:}
      ;;
    *)
      err "unrecognized git remote url: $url"
      ;;
  esac

  REMOTE_HOST=${REMOTE_HOST%%:*}
  REMOTE_PATH=${REMOTE_PATH%.git}
  [[ "$REMOTE_PATH" == */* ]] || err "cannot derive owner/repo from remote: $url"
}

forge_detect() {
  need git
  need jq
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || err "not inside a git repository"

  forge_parse_remote "$(forge_remote_url)"
  # shellcheck disable=SC2034  # OWNER and REPO are consumed by the provider files
  OWNER=${REMOTE_PATH%%/*} REPO=${REMOTE_PATH##*/}

  if [[ -n "${FORGE_PROVIDER:-}" ]]; then
    FORGE="$FORGE_PROVIDER"
    declare -F "${FORGE}_init" >/dev/null ||
      err "unknown FORGE_PROVIDER '${FORGE}' (available: $(forge_providers | tr '\n' ' '))"
  else
    FORGE=""
    local candidate
    for candidate in $(forge_providers); do
      if "${candidate}_probe"; then
        FORGE="$candidate"
        break
      fi
    done
    [[ -n "$FORGE" ]] ||
      err "cannot tell which forge hosts '${REMOTE_HOST}' - set FORGE_PROVIDER to one of: $(forge_providers | tr '\n' ' ')"
  fi

  forge init
}
