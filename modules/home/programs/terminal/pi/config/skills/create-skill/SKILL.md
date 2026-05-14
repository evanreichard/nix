---
name: create-skill
description: 'Create a new skill in the skills directory. Use when user asks to add a skill, create a skill, or mentions "/create-skill". Produces a SKILL.md with frontmatter and optional helper scripts, following conventions from existing skills.'
---

# Create Skill

## Overview

Scaffold a new skill directory with a `SKILL.md` and optional helper scripts under the project's skills directory.

## Workflow

### 1. Gather Requirements

Ask the user:

- **What does the skill do?** (trigger conditions, purpose)
- **Are there repeatable commands?** (if yes, these become scripts)

If the user already provided enough detail, skip straight to drafting.

### 2. Draft the Skill

Create `skills/<skill-name>/SKILL.md` with this structure:

```markdown
---
name: <skill-name>
description: "<One-liner: what it does and when to trigger. Keep under ~200 chars.>"
---

# <Skill Title>

## Overview

[1-2 sentences on purpose and scope]

## Workflow

[Numbered steps the agent follows]
```

**Guidelines:**

- **Be concise.** Skills are injected into agent context — every line costs tokens. Aim for the minimum needed to reliably guide the agent.
- **Use scripts for repeatable logic.** If a step involves a multi-line shell command, `jq` pipeline, or API call that won't change between runs, put it in a `.sh` file next to `SKILL.md` and reference it from the workflow. See `address-gh-review/` for an example.
- **Frontmatter is required.** `name` and `description` fields. The description is what the agent uses to decide whether to load the skill, so make it specific about trigger conditions.
- **Don't over-specify.** Trust the agent to fill gaps. Document the _what_ and _when_, not every micro-step.
- **Split workflow from reference when the reference surface grows.** If a skill accumulates lookup tables, mapping rules, or capability references that the workflow consults, move them into a sibling `<skill>/<category>/` directory (e.g. `mappings/`, `references/`) with one sub-doc per category and an index `README.md`. Keep `SKILL.md` focused on the hot path — workflow, hard rules, and a short table pointing at the sub-docs. Include a brief style guide in the index README covering (a) defer to authoritative sources (stubs, schemas, generated docs) whenever possible, (b) row/entry formatting conventions, (c) when to create a new sub-doc vs. extend an existing one.

### 3. Present for Review

Show the user the draft and wait for approval before finalizing. Apply any requested changes.

### 4. Git Add

Run `git add` on the new skill directory so the flake/tooling can discover it.
