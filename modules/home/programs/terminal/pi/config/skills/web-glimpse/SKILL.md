---
name: web-glimpse
description: 'Search the web, read pages, extract content, run JavaScript, or capture screenshots using the `glimpse` headless browser tool. Use when the user asks to search the web, look something up online, read/fetch a page, inspect dynamic content, or capture visual state. Does not replace curl for simple HTTP/API requests.'
---

# Web Browsing With Glimpse

`glimpse` runs headless Firefox via WebDriver. Use it for web search, reading rendered pages, running JavaScript, and screenshots. Prefer `curl` for simple APIs, static files, and direct downloads.

## Commands

| Command | Purpose |
| ------- | ------- |
| `reader <url>` | Extract page content as Markdown (Reader View → raw fallback) |
| `exec <url>` | Run JavaScript on a page, return the result |
| `screenshot <url>` | Save a PNG screenshot |
| `search <query>` | Search the web (Kagi) and return results |
| `serve` | Start a persistent browser for faster repeat commands |

## Persistent Server

For multi-command sessions, start a persistent browser server first. All subsequent commands auto-discover it via Unix socket — no extra flags needed.

```bash
# Start persistent server (keeps geckodriver + Firefox alive)
glimpse serve &

# All commands now reuse the running browser (~300ms vs ~2-3s each)
glimpse reader https://example.com
glimpse reader https://other.com
glimpse exec https://example.com --js='return document.title'

# Check server status
glimpse serve --status

# Stop when done
glimpse serve --stop
```

State (cookies, localStorage) persists between commands — this is intentional for sticky sessions. Without a running server, commands work normally with ad-hoc browser startup.

## Quick Reference

```bash
# Read a page (tries Reader View, falls back to raw Turndown)
glimpse reader https://example.com --timeout=15

# Read without Reader View (raw HTML → Markdown via Turndown)
glimpse reader https://example.com --no-reader --timeout=15

# Get structured JSON instead of Markdown (includes method: "reader"|"raw")
glimpse reader https://example.com --format=json

# Save extracted content to a file
glimpse reader https://example.com --output=page.md

# Run JavaScript and return a value
glimpse exec https://example.com --js='return document.title'

# Extract specific data with JavaScript
glimpse exec https://example.com --wait-until=complete --js='return {
  title: document.title,
  text: document.body.innerText.slice(0, 4000)
}'

# Wait for dynamic content before extracting
glimpse reader https://example.com \
  --wait-js='return document.querySelector(".content")?.innerText?.length > 100' \
  --timeout=30

# Capture a screenshot
glimpse screenshot https://example.com --output=page.png

# Search the web
glimpse search "query terms" --timeout=15

# Search and get JSON instead of Markdown
glimpse search "query terms" --format=json
```

## Common Options

| Option | Default | Purpose |
| ------ | ------- | ------- |
| `--timeout=<s>` | `10` | Max wait time in seconds; increase for slow/JS-heavy pages |
| `--wait-until=<state>` | `none` | Wait for `none`, `interactive`, or `complete` |
| `--wait-js=<code>` | — | Poll JS expression until truthy |
| `--js=<code>` | — | Run inline JS before command logic |
| `--script=<file>` | — | Run JS file before command logic |
| `--no-headless` | — | Show the browser window |
| `--format=<fmt>` | varies | Output format (reader: `markdown`/`html`/`text`/`json`; search: `markdown`/`json`) |
| `--output=<file>` | — | Write output to file (reader, screenshot) |
| `--no-reader` | — | Skip Reader View, use raw page extraction |

## Workflow

1. **Search first** when the user asks an open-ended question. Pick authoritative results to read.
2. **Read pages with `reader`** — it tries Firefox Reader View for clean article extraction, then falls back to converting the raw page HTML to Markdown via Turndown. Most pages work without extra options.
3. **Add `--wait-until=complete`** for JS-heavy pages, SPAs, or pages that load content dynamically.
4. **Use `exec`** when you need targeted data extraction via JavaScript rather than full page content.
5. **Use `screenshot`** when visual layout, charts, or rendering state matters.
6. **Increase timeouts** — start at `15`, go to `30` for slow sites. The default `10` is often too tight for real-world pages.
7. **Cite URLs** when summarizing web research. Distinguish search snippets from verified page content.

## Error Handling

| Error | Fix |
| ----- | --- |
| `TIMEOUT` | Increase `--timeout` (in seconds), add `--wait-until=complete`, or use `--wait-js` |
| `USAGE_ERROR` | Check arg order: `glimpse <command> <url>`, search is `glimpse search "query"` |
| Thin/empty content | Try `--wait-until=complete`, `--no-reader`, or targeted `exec` |
| Search auth errors | Kagi token is configured via `~/.config/glimpse/config.json` or `KAGI_TOKEN` env |
