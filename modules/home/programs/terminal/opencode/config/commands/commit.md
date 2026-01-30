---
description: Create a conventional commit from git changes
agent: build
---

Run git commands to ensure all changes are staged, then generate a conventional commit message based on the diff and create the commit.

Steps:

1. Add all files (including untracked) using `git add -A`
2. Show the current diff with `git diff --cached` and `git diff --staged`
3. Analyze the changes and create a conventional commit message following the format:
   - Type (feat, fix, docs, style, refactor, test, chore, etc.)
   - Scope (optional, e.g., "runtime", "functions")
   - Subject (brief description, imperative mood)
   - Body (detailed explanation, optional)
4. Execute `git commit -m "message"` with the generated message
5. Show the commit result with `git log -1 --stat`

Conventional commit format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

Common types:

- feat: New feature
- fix: Bug fix
- docs: Documentation changes
- style: Code style changes (formatting, semicolons, etc.)
- refactor: Code refactoring (neither bug fix nor feature)
- test: Adding or updating tests
- chore: Maintenance tasks
- perf: Performance improvements
- ci: CI/CD changes
- build: Build system or dependencies
- revert: Revert a previous commit
