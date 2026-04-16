---
name: address-gh-review
description: 'Fetch and address unresolved GitHub PR review comments. Use when user asks to handle PR reviews, address review feedback, mentions "/address-gh-review", or wants to see what reviewers requested. Fetches unresolved threads, presents an actionable summary, and lets the user select which items to address.'
---

# GitHub PR Review

## Overview

Fetch unresolved review threads from the current PR, consolidate them into actionable items, and address selected items — each as a separate commit.

## Prerequisites

- `gh` CLI authenticated and in a repo with an open PR on the current branch
- The `git-commit` skill available for committing changes

## Workflow

### 1. Fetch Review Comments

Run the bundled script to get unresolved threads:

```bash
bash gh_review.sh
```

If the script fails (no PR, not authenticated, etc.), report the error and stop.

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

### 5. Summary

After all selected items are addressed, print a brief summary of what was done.
