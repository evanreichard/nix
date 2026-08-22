---
name: planning
description: 'Create a structured plan before implementing broad or non-trivial changes. Use when user requests a new feature spanning multiple areas, significant refactoring, or explicitly asks to "plan this out". Produces a plan document in _scratch/, waits for user approval, then tracks progress as tasks are completed.'
---

# Planning Workflow Skill

## When to Use

Trigger this workflow when:
- A user requests a **broad or non-trivial change** (e.g. new feature spanning frontend/backend, significant refactoring)
- A user says things like "plan this out", "create a plan", or "do this properly"

Don't trigger for routine multi-file changes like renames, simple bug fixes, or mechanical refactors.

## Rules

### 1. Always Start with a Plan

**Before touching any code**, create a markdown plan in `_scratch/plan-[short-name].md` with:
- A clear title and status
- Clarifications section (if any unknowns)
- Phased tasks as checkboxes (`- [ ]`)

### 2. Ask Clarifying Questions First

When a requirement is **ambiguous or has multiple valid interpretations**:
- List your interpretations
- Ask the user to confirm
- Document answers in the plan's "Clarifications" section

### 3. Wait for User Approval

Present the plan and wait for the user to confirm before implementing. If the user requests changes, update the plan first.

### 4. Update the Plan as You Work

- Change `- [ ]` to `- [x]` for completed items
- Note any deviations from the original plan
- If you discover new tasks, add them with a note explaining why

### 5. Plan Document Format

```markdown
# Plan: [Feature Name]

> **Status**: ⏳ In Progress | ✅ Complete | ❌ Blocked

## Clarifications

- ~~Question?~~ **Answer**

## Tasks

### Phase 1: [Name]
- [ ] Task 1
- [ ] Task 2

### Phase 2: [Name]
- [ ] Task 3

## Rollback Plan (if destructive/irreversible)
[How to undo if needed]
```

## Anti-Patterns

- ❌ Coding before the user approves the plan
- ❌ Making assumptions about ambiguous requirements
- ❌ Plans that are too vague ("update code")
- ❌ Forgetting to update the plan as you work
