#!/usr/bin/env bash
# Skill-local variable store. Values live in <skill-dir>/.vars/<NAME>.
#
# Usage:
#   variable.sh --get NAME           # prints value to stdout, exits 0
#                                    # or prints a self-explaining hint to
#                                    # stderr and exits 2 if unset.
#   variable.sh --set NAME VALUE     # writes value, exits 0.
#
# Callers should treat a non-zero exit as fatal; the stderr message tells
# the caller (agent or user) exactly how to populate the missing value.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
STORE="$SKILL_DIR/.vars"
SELF="$0"

usage() {
    cat >&2 <<EOF
Usage:
  $SELF --get NAME
  $SELF --set NAME VALUE
EOF
    exit 2
}

case "${1:-}" in
    --get)
        [[ $# -eq 2 ]] || usage
        name="$2"
        file="$STORE/$name"
        if [[ ! -f "$file" ]]; then
            cat >&2 <<EOF
$SELF: $name is not set.
Ask the user for the value, then set it:
  $SELF --set $name <value>
EOF
            exit 2
        fi
        cat "$file"
        ;;
    --set)
        [[ $# -eq 3 ]] || usage
        name="$2"; value="$3"
        [[ "$name" =~ ^[A-Z][A-Z0-9_]*$ ]] || {
            echo >&2 "$SELF: invalid name '$name' (must match [A-Z][A-Z0-9_]*)"
            exit 2
        }
        mkdir -p "$STORE"
        # Self-ignore the store so values never get committed, even if the
        # skill root lacks a .gitignore entry for .vars/.
        [[ -f "$STORE/.gitignore" ]] || printf '*\n' > "$STORE/.gitignore"
        printf '%s' "$value" > "$STORE/$name"
        ;;
    *)
        usage
        ;;
esac
