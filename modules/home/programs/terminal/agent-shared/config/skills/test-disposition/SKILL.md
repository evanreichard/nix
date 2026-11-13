---
name: test-disposition
description: 'Decide whether a test still earns its place: classify each as preserve/adapt/replace/remove/investigate from the contract it protects, and report a disposition table. Use when tests fail after a redesign, when a change needs shims only to keep tests green, when auditing or trimming a test suite, when a suite is green but you do not trust it, or when asked whether a test is still relevant.'
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

A green suite is not evidence. Before classifying, find the tests that cannot fail: break the behaviour each one names and check that it notices. Where the repo has a mutation runner, that is the tool — read its survivors instead of reading tests. Where it does not, mutate by hand: one edit to the decision, one test file, revert. A test that still passes has no contract, whatever its assertion says, and is Replace, not Preserve. This step is where the findings are; classification is the paperwork afterwards.

### 3. Classify each test

| Decision    | Applies when                                                        | Action                                                                            |
| ----------- | ------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Preserve    | The contract it protects still holds                                 | Leave it alone. Needing edits to keep passing means it was Adapt.                 |
| Adapt       | Contract holds, the internals it assumes have changed                | Keep the assertion, rewrite the setup and collaborators.                          |
| Replace     | The behavior moved to a different seam, or the test guards the wrong layer | Delete the old test, write the equivalent at the seam that now owns the behavior. |
| Remove      | The requirement is gone, or other tests already cover it             | Delete it, and say where that coverage lives now or that it is deliberately gone. |
| Investigate | Unclear whether the requirement survives                             | Stop and ask. Guess-and-preserve is the failure mode this skill exists to stop.   |

Adapt, Replace and Remove each name what moved: the assertion that carries the contract now, the seam that owns the behaviour, or the test that covers the requirement. "Renamed for clarity" is Adapt, because a name is part of the contract — a test whose name promises two behaviours and asserts one is a defect, not a style note.

When a test's only subject has no production caller, delete the production code with it. Keeping a helper alive so its test keeps passing is the same failure as keeping the test for the design's sake.

### 4. Report before you commit

One row per test you would change, and one line per module for Preserve. The table exists for decisions, not inventory: a suite-wide audit reported as 300 rows is a wall nobody reads.

| Test                      | Decision | Reason                                                                       |
| ------------------------- | -------- | ---------------------------------------------------------------------------- |
| `test_customer_checkout`  | Preserve | Public checkout contract unchanged                                            |
| `test_redis_cache_calls`  | Remove   | Redis-specific architecture retired; cache behavior covered by `test_cache_store` |
| `test_repository_mocking` | Replace  | Repository layer eliminated; equivalent asserts on the store interface        |
| `test_retry_behavior`     | Adapt    | Same retry contract, mechanism moved from decorator to client                 |

Any `Investigate` row means the report is unfinished — resolve it with the user.

### 5. Apply the dispositions

Edit in the same change as the code the tests cover. Removed tests are deleted from the file, not skipped, quarantined, or disabled behind a flag. Then re-run the mutation check from step 2: a survivor is a gap the audit did not find, and an entry in the repo's mutation list is how a live decision stops depending on somebody re-reading the suite.

## Hard Rules

- Every Remove row names where its requirement is validated now, or states that coverage is deliberately dropped and why.
- Coverage parity is the bar: the suite afterward covers every live requirement the suite before it covered.
- Tests asserting that a collaborator was called, and nothing about the result, are asserting an implementation choice. Classify them by the behavior the caller must produce.
- Production code exists for the design, not to keep a deprecated test green.
- A test that passes is not a test that can fail. Tautologies on booleans, an expectation literal that cannot equal the input under test, an assertion satisfied by some other code path, an `or` that passes on any outcome, and a private accessor's identity instead of the observable effect are the recurring ways this happens — check for them explicitly.
- Assert at the boundary the caller sees (socket, HTTP response, rendered markup, accepted connections) rather than at a collaborator's arguments or a private handle. Wire-shape assertions are the exception when both ends of the protocol live in the repo, and they say so in a comment.
