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

1. **KISS / YAGNI**: Keep solutions simple. Avoid abstractions, generics, or indirection unless there is a concrete need.

2. **Maintain AGENTS.md**: Keep project guidance up to date, but BLUF: concise, actionable, and context-size conscious.

3. **Knowledge Capture Check**: Before the final response, ask whether the task revealed a non-obvious convention, pitfall, repeatable workflow, or missing helper. If yes, briefly recommend exactly where to capture it: package/project AGENTS.md, global AGENTS.md, a skill, or a helper script. Skip this note when there is nothing meaningful.

## Style

### Comment Style

A logical block of code (not necessarily a language scope) should have a short Title Case comment above it:

```go
// Map Component Results
for _, comp := range components {
    results[comp.Name] = comp.Result
}
```

If the block is more complicated or non-obvious, explain _why_ after the title:

```go
// Map Component Results - Downstream consumers expect a name-keyed lookup.
for _, comp := range components {
    results[comp.Name] = comp.Result
}
```
