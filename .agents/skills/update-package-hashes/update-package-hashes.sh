#!/usr/bin/env bash
#
# update-package-hashes.sh — Helper for the update-package-hashes skill.
# Co-located in .agents/skills/update-package-hashes/
#
# Usage:
#   ./update-package-hashes.sh releases <git-url> [pattern]
#   ./update-package-hashes.sh hash <git-url> <rev-or-tag>
#   ./update-package-hashes.sh hash <git-url> <rev-or-tag> <fetcher>
#   ./update-package-hashes.sh all <git-url> <rev-or-tag> [fetcher]
#
# Examples:
#   ./update-package-hashes.sh releases https://github.com/ggml-org/llama.cpp
#   ./update-package-hashes.sh releases https://github.com/ggml-org/llama.cpp b*
#   ./update-package-hashes.sh hash https://github.com/owner/repo v1.2.3
#   ./update-package-hashes.sh hash https://github.com/owner/repo abc1234 fetchFromGitLab
#   ./update-package-hashes.sh all https://github.com/owner/repo v1.2.3

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  $0 releases <git-url> [tag-pattern]
    Show main branch HEAD + 5 most recent matching releases/tags.

  $0 hash <git-url> <rev-or-tag> [fetcher]
    Fetch source and print the nix fetcher expression with hash (via nurl).

  $0 all <git-url> <rev-or-tag> [fetcher]
    Same as hash, but also shows main HEAD + recent releases for context.

Options:
  tag-pattern   Glob pattern for filtering tags (e.g. 'v*', 'b*').
                If omitted, all tags are shown.
  fetcher       Override the auto-detected fetcher:
                  fetchFromGitHub (default)
                  fetchFromGitLab
                  fetchFromGitLab (e.g. gitea.va.reichard.io)
                  fetchFromSourceHut
                  fetchgit (fallback for non-standard forges)

Requires: nix (for nurl), git.
EOF
  exit 1
}

# ── Helpers ──────────────────────────────────────────────────────────────────

detect_fetcher() {
  local url="$1"
  local host
  host=$(echo "$url" | sed -E 's|^https?://||' | cut -d/ -f1)

  case "$host" in
    *github.com)
      echo "fetchFromGitHub"
      ;;
    *gitlab.com)
      echo "fetchFromGitLab"
      ;;
    *gitea*|*gitlab.reichard*|*gitlab.va.reichard*)
      echo "fetchFromGitLab"
      ;;
    *sourcehut*)
      echo "fetchFromSourceHut"
      ;;
    *)
      echo "fetchgit"
      ;;
  esac
}

normalise_url() {
  echo "${1%.git}"
}

# ── Commands ─────────────────────────────────────────────────────────────────

# Show main/master branch HEAD.
show_main_head() {
  local url="$1"
  local clean_url
  clean_url=$(normalise_url "$url")

  for branch in main master; do
    local line
    line=$(git ls-remote "$url" "refs/heads/$branch" 2>/dev/null | head -1)
    if [[ -n "$line" ]]; then
      local full_rev="${line%%	*}"
      echo "  main: ${full_rev:0:12}"
      echo
      return
    fi
  done

  # Fallback: try to find any branch
  echo "  (no main/master branch found)"
  echo
}

# List recent tags/releases for a repo.
cmd_releases() {
  local url="$1"
  local pattern="${2:-}"
  local clean_url
  clean_url=$(normalise_url "$url")

  echo "Recent tags for: $clean_url"
  echo "────────────────────────────────────────────────────────"
  echo

  # Always show main HEAD first
  show_main_head "$url"

  # Get tags sorted by date (newest first), limited to 5
  local tags
  if [[ -n "$pattern" ]]; then
    tags=$(git ls-remote --tags "$url" "$pattern" 2>&1 \
      | grep -v '\^{}' \
      | sed -E 's/^[a-f0-9]+[[:space:]]+refs\/tags\/([^\/]+)[[:space:]]*$/\1/' \
      | sort -V \
      | tail -5)
  else
    tags=$(git ls-remote --tags "$url" 2>&1 \
      | grep -v '\^{}' \
      | sed -E 's/^[a-f0-9]+[[:space:]]+refs\/tags\/([^\/]+)[[:space:]]*$/\1/' \
      | sort -V \
      | tail -5)
  fi

  if [[ -z "$tags" ]]; then
    echo "  (no tags found)"
    return
  fi

  printf "  %-30s  %s\n" "TAG" "COMMIT"
  echo "  $(printf '%.0s-' {1..45})"

  echo "$tags" | tac | while IFS= read -r tag_name; do
    local full_rev
    full_rev=$(git ls-remote "$url" "refs/tags/$tag_name" 2>/dev/null | head -1 | cut -f1)
    if [[ -n "$full_rev" ]]; then
      printf "  %-30s  %s\n" "$tag_name" "${full_rev:0:12}"
    else
      printf "  %-30s  %s\n" "$tag_name" "(not found)"
    fi
  done
}

# Get the nix fetcher expression with hash for a specific rev/tag.
cmd_hash() {
  local url="$1"
  local rev="$2"
  local fetcher="${3:-}"

  if [[ -z "$fetcher" ]]; then
    fetcher=$(detect_fetcher "$url")
  fi

  local clean_url
  clean_url=$(normalise_url "$url")

  echo "Fetching hash for: $clean_url @ $rev"
  echo "Fetcher: $fetcher"
  echo "────────────────────────────────────────────────────────"
  echo

  nix run nixpkgs#nurl -- "$url" "$rev"
}

# Get hash + recent releases for context.
cmd_all() {
  local url="$1"
  local rev="$2"
  local fetcher="${3:-}"

  cmd_releases "$url"
  echo
  cmd_hash "$url" "$rev" "$fetcher"
}

# ── Main ─────────────────────────────────────────────────────────────────────

if [[ $# -lt 2 ]]; then
  usage
fi

case "$1" in
  releases)
    [[ $# -lt 2 ]] && { echo "Error: missing <git-url>" >&2; usage; }
    cmd_releases "$2" "${3:-}"
    ;;
  hash)
    [[ $# -lt 3 ]] && { echo "Error: missing <git-url> <rev-or-tag>" >&2; usage; }
    cmd_hash "$2" "$3" "${4:-}"
    ;;
  all)
    [[ $# -lt 3 ]] && { echo "Error: missing <git-url> <rev-or-tag>" >&2; usage; }
    cmd_all "$2" "$3" "${4:-}"
    ;;
  *)
    echo "Unknown command: $1" >&2
    usage
    ;;
esac
