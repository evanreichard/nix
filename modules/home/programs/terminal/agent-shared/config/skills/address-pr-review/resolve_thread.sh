#!/usr/bin/env bash
# Resolve a PR review thread, optionally reacting or replying first.
#
# Usage:
#   resolve_thread.sh thumbsup <thread-key> [comment-id1 comment-id2 ...]
#   resolve_thread.sh comment "reason" <thread-key>
#
# - thumbsup: adds 👍 to each supplied comment id, then resolves the thread
# - comment:  posts a reply explaining why the thread is being resolved, then resolves
#
# Thread keys and comment ids are opaque and come from review.sh's mapping block.

set -euo pipefail

# shellcheck source=forge.sh
source "$(dirname "${BASH_SOURCE[0]}")/forge.sh"

[[ $# -ge 1 ]] || err "usage: $0 {thumbsup|comment} ..."
ACTION="$1"
shift

forge_detect

case "$ACTION" in
  thumbsup)
    [[ $# -ge 1 ]] || err "usage: $0 thumbsup <thread-key> [comment-id ...]"
    THREAD_KEY="$1"
    shift
    COMMENT_IDS=("$@")

    for cid in "${COMMENT_IDS[@]+"${COMMENT_IDS[@]}"}"; do
      [[ -z "$cid" ]] && continue
      forge react "$cid"
    done

    forge resolve "$THREAD_KEY"
    echo "Resolved thread $THREAD_KEY (thumbs-up on ${#COMMENT_IDS[@]} comment(s))"
    ;;

  comment)
    [[ $# -ge 2 ]] || err "usage: $0 comment \"reason\" <thread-key>"
    REASON="$1"
    THREAD_KEY="$2"

    forge reply "$THREAD_KEY" "$REASON"
    forge resolve "$THREAD_KEY"
    echo "Resolved thread $THREAD_KEY (commented: $REASON)"
    ;;

  *)
    err "unknown action: $ACTION (expected thumbsup|comment)"
    ;;
esac
