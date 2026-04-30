#!/usr/bin/env bash
# Fetch unresolved PR review threads, formatted for LLM consumption.
# Omits diff hunks (the LLM can read files from the repo directly).
# Groups comments into threads so conversation context is preserved.
# Appends a compact thread mapping block at the end with item numbers,
# thread IDs, and comment IDs for downstream resolution.

set -euo pipefail

err() { echo "error: $1" >&2; exit 1; }

# Verify gh CLI is installed
command -v gh >/dev/null 2>&1 || err "'gh' CLI not found. Install it from https://cli.github.com"

# Verify we're inside a git repository
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || err "not inside a git repository"

# Verify the remote is a GitHub repo
gh repo view --json name -q .name >/dev/null 2>&1 || err "this repo does not appear to be hosted on GitHub"

# Verify we're on a PR branch
PR_NUM=$(gh pr view --json number -q .number 2>/dev/null) || err "no pull request found for the current branch"

# Fetch current user, repo owner, and repo name
ME=$(gh api user -q .login 2>/dev/null) || err "failed to fetch GitHub user - are you authenticated? Run 'gh auth login'"
OWNER=$(gh repo view --json owner -q .owner.login 2>/dev/null) || err "failed to determine repository owner"
REPO=$(gh repo view --json name -q .name 2>/dev/null) || err "failed to determine repository name"

# Fetch Unresolved Review Threads via GraphQL
QUERY=$(cat <<EOF
query {
  repository(owner: "${OWNER}", name: "${REPO}") {
    pullRequest(number: ${PR_NUM}) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          comments(first: 100) {
            nodes {
              id
              author { login }
              body
              path
              line
            }
          }
        }
      }
    }
  }
}
EOF
)

RAW_JSON=$(gh api graphql -f query="$QUERY" 2>/dev/null | jq -c '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)') || err "GraphQL query failed - check your permissions and token scopes"

# Build human-readable output + thread mapping block
OUTPUT=""
MAPPING=""
ITEM_NUM=0

while IFS= read -r thread; do
  [[ -z "$thread" ]] && continue

  THREAD_ID=$(echo "$thread" | jq -r '.id')
  FILE=$(echo "$thread" | jq -r '.comments.nodes[0].path')
  LINE=$(echo "$thread" | jq -r '.comments.nodes[0].line')

  # Collect comment IDs (for reactions) — exclude own comments
  COMMENT_IDS=$(echo "$thread" | jq -r --arg me "$ME" '[.comments.nodes[] | select(.author.login != $me) | .id] | join(" ")')

  # Build human-readable comments (exclude own comments)
  COMMENTS=$(echo "$thread" | jq -r --arg me "$ME" '[.comments.nodes[] | select(.author.login != $me) | "- **\(.author.login)**: \(.body)"] | join("\n")')

  if [[ -z "$COMMENTS" ]]; then
    continue
  fi

  ITEM_NUM=$((ITEM_NUM + 1))

  # Append human-readable block
  OUTPUT+="## ${FILE}:${LINE}
${COMMENTS}

"

  # Append mapping line
  MAPPING+="${ITEM_NUM}  ${THREAD_ID}  ${COMMENT_IDS}
"
done <<< "$RAW_JSON"

# Format output
if [[ -z "$OUTPUT" ]]; then
  echo "No unresolved review comments found."
else
  echo "$OUTPUT"
  echo "---"
  echo "# Thread Mapping (item_num | thread_id | comment_ids)"
  echo "$MAPPING"
fi
