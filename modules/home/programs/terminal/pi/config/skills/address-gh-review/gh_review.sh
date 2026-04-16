#!/usr/bin/env bash
# Fetch unresolved PR review threads, formatted for LLM consumption.
# Omits diff hunks (the LLM can read files from the repo directly).
# Groups comments into threads so conversation context is preserved.

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

# Fetch unresolved review threads via GraphQL
OUTPUT=$(gh api graphql -f query='
query {
  repository(owner: "'"$OWNER"'", name: "'"$REPO"'") {
    pullRequest(number: '"$PR_NUM"') {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          comments(first: 100) {
            nodes {
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
}' --jq '
[
  .data.repository.pullRequest.reviewThreads.nodes[]
  | select(.isResolved == false)
  | {
      file: .comments.nodes[0].path,
      line: .comments.nodes[0].line,
      comments: [
        .comments.nodes[]
        | select(.author.login != "'"$ME"'")
        | {author: .author.login, body: .body}
      ]
    }
  | select(.comments | length > 0)
]
| .[]
| "## \(.file):\(.line)\n\(.comments | map("- **\(.author)**: \(.body)") | join("\n"))\n"
' 2>/dev/null) || err "GraphQL query failed - check your permissions and token scopes"

# Format output
if [[ -z "$OUTPUT" ]]; then
  echo "No unresolved review comments found."
else
  echo "$OUTPUT" | sed 's/\\n/\n/g'
fi
