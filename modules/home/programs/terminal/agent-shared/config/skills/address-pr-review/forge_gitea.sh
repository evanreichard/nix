#!/usr/bin/env bash
# Gitea provider, also covering Forgejo (same /api/v1 review endpoints).
#
# Gitea has no review-thread object: a conversation is every code comment sharing a
# (path, line) pair, and the UI reads the resolved flag off the oldest comment of that
# group. Thread keys are therefore "<path>@<line>", where a negative line means the old
# side of the diff, and resolving a thread means marking that oldest comment.

# Gitea Api Host - SSH remotes often use a dedicated alias host (ssh.gitea.example.com)
# that serves no HTTP API, so the leading label is dropped. GITEA_URL overrides the guess.
gitea_web_url() { echo "${GITEA_URL:-https://${REMOTE_HOST#ssh.}}"; }

gitea_probe() {
  need curl
  curl -sS --fail --max-time 5 "$(gitea_web_url)/api/v1/version" 2>/dev/null |
    jq -e 'has("version")' >/dev/null 2>&1
}

gitea_init() {
  GITEA_API="$(gitea_web_url)/api/v1"

  [[ -n "${GITEA_TOKEN:-}" ]] ||
    err "GITEA_TOKEN is unset - create one under Settings > Applications with 'write:repository', 'write:issue' and 'read:user' scopes"

  # shellcheck disable=SC2034  # consumed by review.sh, which sources this file
  ME=$(gitea_api GET /user | jq -r '.login') || err "GITEA_TOKEN rejected by ${GITEA_API}"

  local branch
  branch=$(git branch --show-current)
  [[ -n "$branch" ]] || err "detached HEAD - check out the pull request branch"

  PR_NUM=$(gitea_paged "/repos/${OWNER}/${REPO}/pulls?state=open" | jq -sr --arg b "$branch" '
    (add // []) | map(select(.head.ref == $b)) | first | .number // empty')
  [[ -n "$PR_NUM" ]] || err "no open pull request for branch '${branch}' in ${OWNER}/${REPO}"
}

gitea_api() {
  local method="$1" path="$2"
  shift 2
  curl -sS --fail-with-body -X "$method" \
    -H "Authorization: token ${GITEA_TOKEN}" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "$@" "${GITEA_API}${path}"
}

# gitea_paged - Gitea caps page size at MAX_RESPONSE_ITEMS (50 by default), so list
# endpoints have to be walked until a short page comes back. A non-array page means the
# endpoint answered with an error object instead of a list, which ends the walk rather
# than crashing jq. Each page prints as its own json array; callers merge with
# `jq -s 'add // []'`.
gitea_paged() {
  local path="$1" page=1 join="?" body count
  [[ "$path" == *"?"* ]] && join="&"

  while :; do
    body=$(gitea_api GET "${path}${join}page=${page}&limit=50")
    count=$(jq 'if type == "array" then length else 0 end' <<<"$body")
    [[ "$count" -eq 0 ]] && break
    printf '%s\n' "$body"
    [[ "$count" -lt 50 ]] && break
    page=$((page + 1))
  done
}

gitea_threads() {
  gitea_code_comments | jq -c '
    group_by(.path + "\u0000" + (.line | tostring))
    | map(sort_by(.id))
    | map(select(.[0].resolver == null))
    | map({
        key: (.[0].path + "@" + (.[0].line | tostring)),
        path: .[0].path,
        line: .[0].line,
        comments: map({ id: .id, login: (.user.login // "unknown"), body: .body })
      })
    | .[]'
}

# gitea_code_comments - Every code comment on the PR as one array, with the diff side
# folded into a signed `line` (positive: new side, negative: old side).
gitea_code_comments() {
  local review_ids id
  review_ids=$(gitea_paged "/repos/${OWNER}/${REPO}/pulls/${PR_NUM}/reviews" | jq -sr '(add // []) | .[].id')

  for id in $review_ids; do
    gitea_api GET "/repos/${OWNER}/${REPO}/pulls/${PR_NUM}/reviews/${id}/comments"
  done | jq -s '
    [.[] | select(type == "array") | .[]]
    | map(select(.path != null and .path != ""))
    | map(. + { line: (if .position > 0 then .position else -.original_position end) })'
}

gitea_thread_anchor() {
  local key="$1" path line
  path=${key%@*}
  line=${key##*@}
  gitea_code_comments | jq -r --arg p "$path" --argjson l "$line" '
    map(select(.path == $p and .line == $l)) | sort_by(.id) | first | .id // empty'
}

# Reactions Need write:issue - Cosmetic, so a rejected reaction never fails the resolve.
gitea_react() {
  gitea_api POST "/repos/${OWNER}/${REPO}/issues/comments/${1}/reactions" --data '{"content":"+1"}' >/dev/null 2>&1 || true
}

# Gitea Replies Are Reviews - There is no reply endpoint; a new single-comment review on
# the same (path, line) lands in the same conversation.
gitea_reply() {
  local key="$1" body="$2" path line field payload
  path=${key%@*}
  line=${key##*@}

  if ((line < 0)); then
    field="old_position"
    line=$((-line))
  else
    field="new_position"
  fi

  payload=$(jq -n --arg p "$path" --arg b "$body" --arg f "$field" --argjson l "$line" \
    '{ event: "COMMENT", comments: [({ path: $p, body: $b } + { ($f): $l })] }')

  gitea_api POST "/repos/${OWNER}/${REPO}/pulls/${PR_NUM}/reviews" --data "$payload" >/dev/null ||
    err "failed to post reply on thread $key"
}

gitea_resolve() {
  local anchor
  anchor=$(gitea_thread_anchor "$1")
  [[ -n "$anchor" ]] || err "no review comment found for thread $1"

  gitea_api POST "/repos/${OWNER}/${REPO}/pulls/comments/${anchor}/resolve" >/dev/null ||
    err "failed to resolve thread $1"
}
