# AI Agent Guidelines

Be cognizant of context use; this file is loaded for all LLMs. Keep guidance concise and high-signal.

## Critical Rules

1. **Bash timeouts**: Every `bash` tool call MUST specify a timeout.
   ```bash
   bash(command="some command", timeout=30)
   ```

2. **File writing**: Do NOT use `cat` with heredocs to write files. Use `write` for new/rewritten files and `edit` for targeted modifications.

3. **Scratch files**: Put temporary scripts, plans, notes, and reusable exploration artifacts in `_scratch/`. It is gitignored.

4. **Missing commands**: If a tool is not installed, prefer `nix run` instead of installing it.
   ```bash
   nix run nixpkgs#python3 -- script.py
   ```

## Context Discipline

Prefer a **search → targeted read** pattern:

1. Search with `rg -n` / `grep -n` to find relevant line numbers.
2. Read only the needed range with `read(path, offset, limit)`.

Full-file reads are fine when genuinely needed, but avoid them as the default reflex.

## Principles

1. **Priority order**: When goals conflict, optimize in this order:
   1. **Correctness** — solve the actual use case, including the realistic failure modes (not just the happy path).
   2. **Maintainability / readability** — non-negotiable. Code is read far more than it is written; clarity wins over cleverness.
   3. **Abstraction & polish** — only after the above are solid, and only when a concrete need justifies it.

   All three matter, but never sacrifice (2) for (3). Prefer obvious, boring code over slick code that requires a paragraph to explain.

2. **KISS / YAGNI**: Avoid abstractions, generics, or indirection unless there is a concrete, present need. Speculative flexibility is a maintainability tax.

3. **Maintain AGENTS.md**: Keep project guidance up to date, but BLUF: concise, actionable, and context-size conscious.

4. **Knowledge Capture Check**: Before the final response, ask whether the task revealed a non-obvious convention, pitfall, repeatable workflow, or missing helper. If yes, briefly recommend exactly where to capture it: package/project AGENTS.md, global AGENTS.md, a skill, or a helper script. Skip this note when there is nothing meaningful.

## Style

### Comment Style

Default to **no comment**. Code should be self-explanatory through naming and structure. Only add a comment when it earns its place by explaining something the code cannot.

Write a comment when, and only when:

1. The _why_ is non-obvious (intent, constraint, workaround, surprising invariant).
2. A reader familiar with the language/codebase would otherwise stop and ask "why?".

Do not narrate _what_ the code does. Do not add Title Case section headers over logical blocks just to label them.

When a comment _is_ warranted, use a short Title Case label, a dash, and the _why_:

```go
// Map Component Results - Downstream consumers expect a name-keyed lookup.
for _, comp := range components {
    results[comp.Name] = comp.Result
}
```

Rules for the explanation after the dash:

- Keep it to **2–3 sentences max**. Never a paragraph.
- State the _why_ directly. Do not restate what the code does, recap prior context, or hedge.
- Do **not** hard-wrap comments at 80 columns. Up to ~120 is fine.

If a block is complex enough that it needs a heading just to be navigable, that is usually a signal to extract a well-named function instead.
