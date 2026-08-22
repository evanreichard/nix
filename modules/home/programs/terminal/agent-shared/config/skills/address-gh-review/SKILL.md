---
name: address-gh-review
description: 'Fetch and address unresolved GitHub PR review comments. Use when user asks to handle PR reviews, address review feedback, mentions "/address-gh-review", or wants to see what reviewers requested. Fetches unresolved threads, presents an actionable summary, lets the user select which items to address, and resolves threads on GitHub.'
---

# GitHub PR Review

## Overview

Fetch unresolved review threads from the current PR, consolidate them into actionable items, address selected items (each as a separate commit), and resolve threads on GitHub with reactions or explanatory comments.

## Prerequisites

- `gh` CLI authenticated and in a repo with an open PR on the current branch
- The `git-commit` skill available for committing changes

## Scripts

- `gh_review.sh` — Fetches unresolved threads, prints human-readable summary, and appends a compact thread mapping block at the end with item numbers, thread IDs, and comment IDs for downstream resolution.
- `gh_resolve_thread.sh` — Resolves a GitHub review thread, optionally adding reactions or a comment first.

### `gh_resolve_thread.sh` Usage

```bash
# Thumbs-up on comments, then resolve
bash gh_resolve_thread.sh thumbsup <thread-id> [comment-id1 comment-id2 ...]

# Post a reply explaining why, then resolve
bash gh_resolve_thread.sh comment "reason" <thread-id>
```

## Workflow

### 1. Fetch Review Comments

Run the bundled script to get unresolved threads:

```bash
bash gh_review.sh
```

If the script fails (no PR, not authenticated, etc.), report the error and stop.

The script appends a thread mapping block at the end of its output:

```
# Thread Mapping (item_num | thread_id | comment_ids)
1  PRRT_kwDOKhRdjM5-yKNp  PRRC_kwDOKhRdjM6849mq PRRC_kwDOKhRdjM6849mr
2  PRRT_kwDOKhRdjM5-yKOJ  PRRC_kwDOKhRdjM6849nZ
```

Capture these IDs from the script output — they are needed in step 5.

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

### 5. Resolve Threads on GitHub

After all code changes are committed, resolve the corresponding threads on GitHub using the thread IDs and comment IDs from the script output in step 1:

1. For **addressed items**: run `bash gh_resolve_thread.sh thumbsup <thread-id> <comment-ids...>` — adds 👍 to each comment, then resolves the thread.
2. For **skipped items**: ask the user for a brief reason, then run `bash gh_resolve_thread.sh comment "<reason>" <thread-id>` — posts an explanation, then resolves.

Only resolve threads for items the user explicitly selected (addressed or skipped). Leave untouched items unresolved.

### 6. Summary

After all selected items are addressed and threads resolved, print a brief summary of what was done (code changes + thread resolutions).
