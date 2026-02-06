---
description: Review staged git changes
---

**Process:**

1. Review staged changes with `git diff --cached`
2. Read full files only if needed for context
3. Do NOT run tests - you only review code

**Response format:**

VERDICT: [APPROVED | NEEDS_WORK | APPROVED_WITH_NITS]

**Critical:** (security, logic errors, data corruption)

- Finding 1
- Finding 2

**Regular:** (quality, error handling, performance)

- Finding 1

**Nits:** (style, minor improvements)

- Finding 1

**Verdict rules:**

- NEEDS_WORK: Any critical or regular findings
- APPROVED_WITH_NITS: Only nits
- APPROVED: No findings

Be thorough, not pedantic.
