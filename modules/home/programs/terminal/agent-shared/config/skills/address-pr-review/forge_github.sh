#!/usr/bin/env bash
# GitHub provider: review threads are first-class objects, so thread keys are GraphQL
# node ids and every operation is a single mutation.

github_probe() {
  case "$REMOTE_HOST" in
    github.com | *.github.com) return 0 ;;
    *) return 1 ;;
  esac
}

github_init() {
  need gh
  gh repo view --json name -q .name >/dev/null 2>&1 || err "gh cannot read this repository - run 'gh auth login'"
  OWNER=$(gh repo view --json owner -q .owner.login) || err "failed to determine repository owner"
  REPO=$(gh repo view --json name -q .name) || err "failed to determine repository name"
  PR_NUM=$(gh pr view --json number -q .number 2>/dev/null) || err "no pull request found for the current branch"
  # shellcheck disable=SC2034  # consumed by review.sh
  ME=$(gh api user -q .login 2>/dev/null) || err "failed to fetch GitHub user - run 'gh auth login'"
}

github_threads() {
  local query
  query=$(
    cat <<EOF
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

  gh api graphql -f query="$query" 2>/dev/null | jq -c '
    .data.repository.pullRequest.reviewThreads.nodes[]
    | select(.isResolved == false)
    | {
        key: .id,
        path: .comments.nodes[0].path,
        line: .comments.nodes[0].line,
        comments: [.comments.nodes[] | { id: .id, login: (.author.login // "ghost"), body: .body }]
      }' || err "GraphQL query failed - check your permissions and token scopes"
}

github_react() {
  # shellcheck disable=SC2016  # GraphQL uses -f flags, not shell expansion
  gh api graphql -f query='
mutation($subjectId: ID!, $content: ReactionContent!) {
      addReaction(input: { subjectId: $subjectId, content: $content }) {
        reaction { content }
      }
    }' -f subjectId="$1" -f content=THUMBS_UP --jq '.data.addReaction.reaction.content' >/dev/null 2>&1 || true
}

github_reply() {
  # shellcheck disable=SC2016  # GraphQL uses -f flags, not shell expansion
  gh api graphql -f query='
mutation($threadId: ID!, $body: String!) {
      addPullRequestReviewThreadReply(input: { pullRequestReviewThreadId: $threadId, body: $body }) {
        comment { id }
      }
    }' -f threadId="$1" -f body="$2" --jq '.data.addPullRequestReviewThreadReply.comment.id' >/dev/null 2>&1 ||
    err "failed to post reply on thread $1"
}

github_resolve() {
  # shellcheck disable=SC2016  # GraphQL uses -f flags, not shell expansion
  gh api graphql -f query='
mutation($threadId: ID!) {
      resolveReviewThread(input: { threadId: $threadId }) {
        clientMutationId
      }
    }' -f threadId="$1" --jq '.data.resolveReviewThread.clientMutationId' >/dev/null 2>&1 ||
    err "failed to resolve thread $1"
}
