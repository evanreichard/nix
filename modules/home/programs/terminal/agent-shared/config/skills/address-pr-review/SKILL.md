---
name: address-pr-review
description: 'Fetch and address unresolved pull request review comments on GitHub or Gitea. Use when user asks to handle PR reviews, address review feedback, mentions "/address-pr-review", or wants to see what reviewers requested. Fetches unresolved threads, presents an actionable summary, lets the user select which items to address, and resolves threads on the forge.'
---

# PR Review

## Overview

Fetch unresolved review threads from the current PR, consolidate them into actionable items, address selected items (each as a separate commit), and resolve threads on the forge with reactions or explanatory comments.

Each forge is a provider file (`forge_github.sh`, `forge_gitea.sh`); detection asks each one whether it owns the remote host. GitHub matches on hostname, Gitea (and Forgejo) on an unauthenticated `/api/v1/version` fingerprint. `FORGE_PROVIDER=<name>` skips detection.

## Prerequisites

- In a repo with an open PR on the current branch
- GitHub: `gh` CLI authenticated
- Gitea: `GITEA_TOKEN` set to a token with `write:repository`, `write:issue` and `read:user` scopes (`write:issue` is what reactions need; without it the 👍 is skipped and only the resolve happens). The API host is derived from the remote (a leading `ssh.` label is dropped, so `ssh.gitea.example.com` → `https://gitea.example.com`); set `GITEA_URL` to override.
- The `git-commit` skill available for committing changes

## Scripts

- `review.sh` — Fetches unresolved threads, prints human-readable summary, and appends a compact thread mapping block at the end with item numbers, thread keys, and comment ids for downstream resolution.
- `resolve_thread.sh` — Resolves a review thread, optionally adding reactions or a comment first.
- `forge.sh` — Remote parsing, provider detection, and the `forge <op>` dispatcher; sources every `forge_*.sh` beside it. Not run directly.
- `forge_github.sh`, `forge_gitea.sh` — Per-forge implementations of the six-function provider contract documented at the top of `forge.sh`. Adding a forge means adding one such file; nothing else changes.

### `resolve_thread.sh` Usage

```bash
# Thumbs-up on comments, then resolve
bash resolve_thread.sh thumbsup <thread-key> [comment-id1 comment-id2 ...]

# Post a reply explaining why, then resolve
bash resolve_thread.sh comment "reason" <thread-key>
```

## Workflow

### 1. Fetch Review Comments

Run the bundled script to get unresolved threads:

```bash
bash review.sh
```

If the script fails (no PR, not authenticated, etc.), report the error and stop.

The script appends a thread mapping block at the end of its output:

```
# Forge: gitea (evan/nix PR #7)
# Thread Mapping (item_num | thread_key | comment_ids)
1  src/auth/login.ts@42  1183 1184
2  src/utils/validators.ts@89  1191
```

Thread keys are opaque — GitHub node ids, or `<path>@<line>` on Gitea. Pass them back verbatim; never construct them by hand.

Capture these ids from the script output — they are needed in step 5.

### 2. Consolidate into Actionable Items

Parse the output and group into actionable items. Combine threads that ask for the same change (e.g. multiple reviewers commenting on the same function about the same concern). Keep items separate when they require distinct code changes.

Present a numbered list to the user:

```
## Unresolved Review Items

1. **src/auth/login.ts:42** — Add rate limiting to prevent brute force attacks (alice-dev)
2. **src/utils/validators.ts:89** — Use stricter type checking for email validation (bob-coder)
3. **src/api/users.ts:156** — Add error handling for null responses (alice-dev, charlie-reviewer)
```

### 3. Ask User for Selection

**Always ask before proceeding.** Prompt the user to select which items to address:

```
Which items would you like me to address? (e.g. "1,3", "all", or "none")
```

**Do not proceed until the user responds.** Respect "none" — just stop.

### 4. Address Each Item

For each selected item, in order:

1. Read the relevant file and understand the context around the referenced line
2. Implement the requested change
3. Run relevant linting/tests if applicable (e.g. `quicklint`)
4. Commit using the `git-commit` skill — **one commit per item**

### 5. Resolve Threads

After all code changes are committed, resolve the corresponding threads using the thread keys and comment ids from the script output in step 1:

1. For **addressed items**: run `bash resolve_thread.sh thumbsup <thread-key> <comment-ids...>` — adds 👍 to each comment, then resolves the thread.
2. For **skipped items**: ask the user for a brief reason, then run `bash resolve_thread.sh comment "<reason>" <thread-key>` — posts an explanation, then resolves.

Only resolve threads for items the user explicitly selected (addressed or skipped). Leave untouched items unresolved.

### 6. Summary

After all selected items are addressed and threads resolved, print a brief summary of what was done (code changes + thread resolutions).
