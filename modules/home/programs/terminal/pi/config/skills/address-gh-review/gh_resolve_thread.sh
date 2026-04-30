#!/usr/bin/env bash
# Resolve a GitHub PR review thread, optionally adding reactions or a comment.
#
# Usage:
#   gh_resolve_thread.sh thumbsup <thread-id> [comment-id1 comment-id2 ...]
#   gh_resolve_thread.sh comment "reason" <thread-id>
#
# - thumbsup: adds 👍 to each supplied comment ID, then resolves the thread
# - comment:  posts a reply explaining why the thread is being resolved, then resolves
#
# Requires: gh CLI authenticated, running on a branch with an open PR.

set -euo pipefail

err() { echo "error: $1" >&2; exit 1; }

command -v gh >/dev/null 2>&1 || err "'gh' CLI not found"

if [[ $# -lt 1 ]]; then
  err "usage: $0 {thumbsup|comment} ..."
fi
ACTION="$1"
shift

case "$ACTION" in
  thumbsup)
    [[ $# -lt 1 ]] && err "usage: $0 thumbsup <thread-id> [comment-id ...]"
    THREAD_ID="$1"
    shift
    COMMENT_IDS=("$@")

    # Add thumbs-up reaction to each comment
    for cid in "${COMMENT_IDS[@]+"${COMMENT_IDS[@]}"}"; do
      [[ -z "$cid" ]] && continue
      # shellcheck disable=SC2016  # GraphQL uses -f flags, not shell expansion
      gh api graphql -f query='
mutation($subjectId: ID!, $content: ReactionContent!) {
      addReaction(input: { subjectId: $subjectId, content: $content }) {
        reaction { content }
      }
    }' -f subjectId="$cid" -f content=THUMBS_UP --jq '.data.addReaction.reaction.content' >/dev/null 2>&1 || true
    done

    # Resolve the thread
    # shellcheck disable=SC2016  # GraphQL uses -f flags, not shell expansion
    gh api graphql -f query='
mutation($threadId: ID!) {
      resolveReviewThread(input: { threadId: $threadId }) {
        clientMutationId
      }
    }' -f threadId="$THREAD_ID" --jq '.data.resolveReviewThread.clientMutationId' >/dev/null 2>&1 || err "failed to resolve thread $THREAD_ID"

    echo "Resolved thread $THREAD_ID (thumbs-up on ${#COMMENT_IDS[@]} comment(s))"
    ;;

  comment)
    [[ $# -lt 2 ]] && err "usage: $0 comment \"reason\" <thread-id>"
    REASON="$1"
    THREAD_ID="$2"

    # Post a reply on the thread
    # shellcheck disable=SC2016  # GraphQL uses -f flags, not shell expansion
    gh api graphql -f query='
mutation($threadId: ID!, $body: String!) {
      addPullRequestReviewThreadReply(input: { pullRequestReviewThreadId: $threadId, body: $body }) {
        comment { id }
      }
    }' -f threadId="$THREAD_ID" -f body="$REASON" --jq '.data.addPullRequestReviewThreadReply.comment.id' >/dev/null 2>&1 || err "failed to post reply on thread $THREAD_ID"

    # Resolve the thread
    # shellcheck disable=SC2016  # GraphQL uses -f flags, not shell expansion
    gh api graphql -f query='
mutation($threadId: ID!) {
      resolveReviewThread(input: { threadId: $threadId }) {
        clientMutationId
      }
    }' -f threadId="$THREAD_ID" --jq '.data.resolveReviewThread.clientMutationId' >/dev/null 2>&1 || err "failed to resolve thread $THREAD_ID"

    echo "Resolved thread $THREAD_ID (commented: $REASON)"
    ;;

  *)
    err "unknown action: $ACTION (expected thumbsup|comment)"
    ;;
esac
