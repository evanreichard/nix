---
name: architecture-review
description: 'Establish the target architectural state — boundaries, state ownership, contracts, invariants — before touching code or tests in a structural change, then validate the result against it. Use when asked to review or restructure module boundaries, or when a change spans several components and existing tests would otherwise drive the design.'
---

# Architecture Review

## Overview

Describe the architecture as **state**, not as work. The deliverable is the structure the code is in when the change is done: boundaries, ownership, contracts. Sequencing belongs in the commit history.

## Workflow

### 1. Current state

Write the structure as it exists, citing files:

- Modules and the responsibility each holds.
- Dependency direction between them.
- Who owns each piece of mutable state, and where it is mutated.
- Where contracts live today (types, interfaces, schemas, events).
- Places where one module reaches into another's internals.

### 2. Target state

The same list for the end state:

- Boundary map: which modules exist, what each owns, what it may depend on.
- State ownership: one owner per piece of mutable state.
- Contract per boundary: what callers may rely on, what stays internal.
- Invariants the structure guarantees (ordering, isolation, single writer, idempotence).
- Behavior that must remain externally identical, stated as a contract entry.

Describe conditions, not steps. "The parser no longer knows about the session store" is a state; "extract the parser, then remove the store reference" is a plan.

### 3. Delta

What moves, splits, merges, or disappears between current and target. If the delta cannot be expressed without ordering language, two boundaries are still tangled — return to step 2.

### 4. Confirm the contracts

Present the target state and its contract changes to the user before implementing. Test dispositions inherit from this map, so an unconfirmed contract lets a rewrite drift into an unintended behavior change.

### 5. Test dispositions

Run the `test-disposition` skill against tests coupled to the affected components, using the target state as the authority for what each test becomes.

### 6. Implement and validate

- Build to the target state, checking each invariant as you go.
- Validate: invariants hold, contracts are asserted at the new boundaries, dependency direction matches step 2.
- Watch for the failure mode this exists to prevent: a layer whose only job is bridging the old structure to the new one.

### 7. Report

Target state, delta, the disposition table, and each invariant with the evidence that it holds.

## Hard Rules

- Structure over chronology: no phases, milestones, or migration sequence in the target state.
- Once a contract is confirmed, a test contradicting it is an Adapt or Replace case — name the contract that changed and move on.
- Preserved behavior is a contract entry too. A test asserting it that fails is a defect, not a candidate for deletion.
