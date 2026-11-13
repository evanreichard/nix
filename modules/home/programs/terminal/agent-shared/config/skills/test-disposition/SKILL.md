---
name: test-disposition
description: 'Decide whether a test still earns its place: classify each as preserve/adapt/replace/remove/investigate from the contract it protects, and report a disposition table. Use when tests fail after a redesign, when a change needs shims only to keep tests green, when auditing or trimming a test suite, or when asked whether a test is still relevant.'
---

# Test Disposition

## Overview

Decide what each test should become, from the contract it protects. Applies to one suspect test or an entire suite.

## Workflow

### 1. Establish the source of truth

Name the authority the classification answers to: a design change, a requirement change, the diff under review, or the module the test claims to cover. If it is unstated, ask before classifying — every disposition depends on it.

### 2. Find the tests in scope

For a change, search tests referencing the changed symbols, modules, or behavior:

```bash
rg -n '<changed symbol>' --glob '*test*' --glob '*spec*'
```

For a cleanup, enumerate the suite and read for overlap: tests asserting the same behavior, and tests asserting that a collaborator was called rather than what the caller produced.

Include tests that currently pass. A passing test that pins a retired structure or duplicates another gets the same review as a failing one. Relevance is separate from flakiness: a flaky test protecting a live contract is Preserve plus a fix.

### 3. Classify each test

| Decision    | Applies when                                                        | Action                                                                            |
| ----------- | ------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Preserve    | The contract it protects still holds                                 | Leave it alone. Needing edits to keep passing means it was Adapt.                 |
| Adapt       | Contract holds, the internals it assumes have changed                | Keep the assertion, rewrite the setup and collaborators.                          |
| Replace     | The behavior moved to a different seam, or the test guards the wrong layer | Delete the old test, write the equivalent at the seam that now owns the behavior. |
| Remove      | The requirement is gone, or other tests already cover it             | Delete it, and say where that coverage lives now or that it is deliberately gone. |
| Investigate | Unclear whether the requirement survives                             | Stop and ask. Guess-and-preserve is the failure mode this skill exists to stop.   |

### 4. Report before you commit

One row per test once more than a couple are in scope; a single test gets one line in the reply:

| Test                      | Decision | Reason                                                                       |
| ------------------------- | -------- | ---------------------------------------------------------------------------- |
| `test_customer_checkout`  | Preserve | Public checkout contract unchanged                                            |
| `test_redis_cache_calls`  | Remove   | Redis-specific architecture retired; cache behavior covered by `test_cache_store` |
| `test_repository_mocking` | Replace  | Repository layer eliminated; equivalent asserts on the store interface        |
| `test_retry_behavior`     | Adapt    | Same retry contract, mechanism moved from decorator to client                 |

Any `Investigate` row means the report is unfinished — resolve it with the user.

### 5. Apply the dispositions

Edit in the same change as the code the tests cover. Removed tests are deleted from the file, not skipped, quarantined, or disabled behind a flag.

## Hard Rules

- Every Remove row names where its requirement is validated now, or states that coverage is deliberately dropped and why.
- Coverage parity is the bar: the suite afterward covers every live requirement the suite before it covered.
- Tests asserting that a collaborator was called, and nothing about the result, are asserting an implementation choice. Classify them by the behavior the caller must produce.
- Production code exists for the design, not to keep a deprecated test green.
