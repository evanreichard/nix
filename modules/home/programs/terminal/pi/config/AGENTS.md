# AI Agent Guidelines

## Important Rules

1. **Timeout for bash tool**: The `bash` tool MUST have a timeout specified. Without a timeout, the tool will hang indefinitely and cause the task to fail.

2. **File writing**: Do NOT use `cat` with heredocs to write files. Use the `write` tool instead (or `edit` for modifications).

3. **Ephemeral files**: Put temporary scripts, plans, notes, and other scratch artifacts in `_scratch/`. It is gitignored, and reusable exploration/testing scripts should be iterated there instead of recreated repeatedly.

## Example of Correct Usage

### Incorrect (will hang):

```bash
bash(command="some long-running command")
```

### Correct (with timeout):

```bash
bash(command="some command", timeout=30)
```

### Incorrect (file writing):

```bash
bash(command="cat > file.txt << 'EOF'\ncontent\nEOF")
```

### Correct (file writing):

```bash
write(path="file.txt", content="content")
```

## Reading Files

Prefer a **search → targeted read** pattern to minimize context usage:

1. **Search** with `grep -n` / `rg -n` to find relevant line numbers.
2. **Read** only the needed range using `read(path, offset, limit)` or `sed -n 'X,Yp'`.

```bash
# Find the relevant lines
bash(command="rg -n 'functionName' src/", timeout=10)

# Read just that region (e.g. lines 42-70)
read(path="src/foo.go", offset=42, limit=29)
```

Full-file reads are fine when genuinely needed (small files, needing full picture), but avoid them as the default reflex.

## Principles

1. **KISS / YAGNI** - Keep solutions simple and straightforward. Don't introduce abstractions, generics, or indirection unless there is a concrete, immediate need. Prefer obvious code over clever code.

2. **Maintain AGENTS.md** - If the project has an `AGENTS.md`, keep it up to date as conventions or architecture evolve. However, follow the **BLUF** (Bottom Line Up Front) principle: keep it concise, actionable, and context-size conscious. Don't overload it with information that belongs in code comments or external docs.

## Style

### Comment Style

A logical "block" of code (doesn't have to be a scope, but a cohesive group of statements responsible for something) should have a comment above it with a short "title". The title must be in **Title Case**. For example:

```go
// Map Component Results
for _, comp := range components {
    results[comp.Name] = comp.Result
}
```

If the block is more complicated or non-obvious, explain _why_ it does what it does after the title:

```go
// Map Component Results - This is needed because downstream consumers
// expect a name-keyed lookup. Without it, the renderer would fall back
// to O(n) scans on every frame.
for _, comp := range components {
    results[comp.Name] = comp.Result
}
```
