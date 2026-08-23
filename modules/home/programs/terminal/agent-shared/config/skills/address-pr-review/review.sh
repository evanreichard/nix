#!/usr/bin/env bash
# Fetch unresolved PR review threads, formatted for LLM consumption.
# Works against GitHub (via `gh`) and Gitea (via its REST API).
# Omits diff hunks (the LLM can read files from the repo directly).
# Groups comments into threads so conversation context is preserved.
# Appends a compact thread mapping block at the end with item numbers,
# thread keys, and comment ids for downstream resolution.

set -euo pipefail

# shellcheck source=forge.sh
source "$(dirname "${BASH_SOURCE[0]}")/forge.sh"

forge_detect

OUTPUT=""
MAPPING=""
ITEM_NUM=0

while IFS= read -r thread; do
  [[ -z "$thread" ]] && continue

  KEY=$(jq -r '.key' <<<"$thread")
  FILE=$(jq -r '.path' <<<"$thread")
  LINE=$(jq -r '.line' <<<"$thread")

  # Own comments are dropped: replies this workflow already posted are not review feedback.
  COMMENT_IDS=$(jq -r --arg me "$ME" '[.comments[] | select(.login != $me) | .id | tostring] | join(" ")' <<<"$thread")
  COMMENTS=$(jq -r --arg me "$ME" '[.comments[] | select(.login != $me) | "- **\(.login)**: \(.body)"] | join("\n")' <<<"$thread")

  [[ -z "$COMMENTS" ]] && continue

  ITEM_NUM=$((ITEM_NUM + 1))

  OUTPUT+="## ${FILE}:${LINE#-}
${COMMENTS}

"

  MAPPING+="${ITEM_NUM}  ${KEY}  ${COMMENT_IDS}
"
done < <(forge threads)

if [[ -z "$OUTPUT" ]]; then
  echo "No unresolved review comments found."
else
  echo "$OUTPUT"
  echo "---"
  echo "# Forge: ${FORGE} (${OWNER}/${REPO} PR #${PR_NUM})"
  echo "# Thread Mapping (item_num | thread_key | comment_ids)"
  echo "$MAPPING"
fi
