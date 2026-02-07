# AI Agent Guidelines

## Important Rules

1. **Timeout for bash tool**: The `bash` tool MUST have a timeout specified. Without a timeout, the tool will hang indefinitely and cause the task to fail.

2. **File writing**: Do NOT use `cat` with heredocs to write files. Use the `write` tool instead (or `edit` for modifications).

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
