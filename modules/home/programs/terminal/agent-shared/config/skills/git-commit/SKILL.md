---
name: git-commit
description: 'Execute git commit with conventional commit message analysis, intelligent staging, and message generation. Use when user asks to commit changes, create a git commit, mentions "/commit", or simply says "do it". Automatically commits without confirmation. Supports: (1) Auto-detecting type and scope from changes, (2) Generating conventional commit messages from diff, (3) Optional type/scope/description overrides, (4) Intelligent file staging for logical grouping'
---

# Git Commit with Conventional Commits

## Overview

Create standardized, semantic git commits using the Conventional Commits specification. Analyze the actual diff to determine appropriate type, scope, and message.

## Automatic Execution — CRITICAL

**When this skill is invoked, EXECUTE THE COMMIT IMMEDIATELY. Do NOT ask for confirmation. Do NOT say "I'm ready" or "let me know when you want to proceed." Do NOT wait for further input. Do NOT acknowledge and then wait.**

The skill is invoked when the user says "commit", "do it", "/commit", "make a commit", "create a commit", or any similar phrase. The moment you recognize this intent, analyze the diff and run `git commit`. That's it.

**Zero prompts. Zero confirmation requests. Zero hand-holding.**

Only skip the commit if:
- Nothing is staged or modified (say "Nothing to commit" and stop)
- Secrets appear to be about to be committed (refuse and stop)

For everything else — just commit.

## Conventional Commit Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Commit Types

| Type       | Purpose                        |
| ---------- | ------------------------------ |
| `feat`     | New feature                    |
| `fix`      | Bug fix                        |
| `docs`     | Documentation only             |
| `style`    | Formatting/style (no logic)    |
| `refactor` | Code refactor (no feature/fix) |
| `perf`     | Performance improvement        |
| `test`     | Add/update tests               |
| `build`    | Build system/dependencies      |
| `ci`       | CI/config changes              |
| `chore`    | Maintenance/misc               |
| `revert`   | Revert commit                  |

## Breaking Changes

```
# Exclamation mark after type/scope
feat!: remove deprecated endpoint

# BREAKING CHANGE footer
feat: allow config to extend other configs

BREAKING CHANGE: `extends` key behavior changed
```

## Workflow

### 1. Analyze Diff

```bash
# If files are staged, use staged diff
git diff --staged

# If nothing staged, use working tree diff
git diff

# Also check status
git status --porcelain
```

### 2. Stage Files (if needed)

If nothing is staged or you want to group changes differently:

```bash
# Stage specific files
git add path/to/file1 path/to/file2

# Stage by pattern
git add *.test.*
git add src/components/*

# Interactive staging
git add -p
```

**Never commit secrets** (.env, credentials.json, private keys).

### 3. Generate Commit Message

Analyze the diff to determine:

- **Type**: What kind of change is this?
- **Scope**: What area/module is affected?
- **Description**: One-line summary of what changed (present tense, imperative mood, <72 chars)

### 4. Execute Commit

```bash
# Single line
git commit -m "<type>[scope]: <description>"

# Multi-line with body/footer
git commit -m "$(cat <<'EOF'
<type>[scope]: <description>

<optional body>

<optional footer>
EOF
)"
```

## Best Practices

- One logical change per commit
- Present tense: "add" not "added"
- Imperative mood: "fix bug" not "fixes bug"
- Reference issues: `Closes #123`, `Refs #456`
- Keep description under 72 characters
- Keep commit bodies short: 4 sentences max.
- If you are unsure whether a body is useful, omit it entirely.

## Git Safety Protocol

- NEVER update git config
- NEVER run destructive commands (--force, hard reset) without explicit request
- NEVER skip hooks (--no-verify) unless user asks
- NEVER force push to main/master
- If commit fails due to hooks, fix and create NEW commit (don't amend)
