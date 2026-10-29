---
name: userscript-test
description: Create, edit, and test browser userscripts by running them in Camoufox (anti-bot Firefox) against real pages or local fixtures, with screenshots, DOM assertions, console logs, and emulated GM_* APIs. Use when building or debugging a *.user.js script, when a userscript needs visual verification, or when checking that a change actually works on a live site.
---

# Userscript Test

Run a userscript in a real, anti-bot-detection Firefox and observe the result. Use it whenever you change a `*.user.js` file and need to know it works - reading the code is not verification.

## Use this skill when

- Creating a new userscript (scaffold, then verify it actually does something).
- Editing an existing one (verify the change, catch regressions).
- Debugging why a script does not fire, styles nothing, or throws.
- Checking behaviour that depends on GM_* APIs, menu commands, storage, or cross-origin requests.

## Setup

The runner is a uv script; dependencies (`camoufox`, `certifi`) resolve on first run. Camoufox's browser is already cached under `~/.cache/camoufox`, so there is nothing to install.

```bash
uv run ~/.pi/agent/skills/userscript-test/scripts/run.py <script.user.js> <url> [options]
```

Run it from the project root so relative paths and `scripts/*.user.js` resolve. If `uv` is missing, the userscripts flake provides it (`flake.nix` already lists `uv`).

## Core loop

1. **Baseline** - run the script against the target page and screenshot it.
2. **Read the render** - open the PNG with the `read` tool. Screenshots come back as images you can actually see; use them to judge layout, contrast, and whether the change is visible.
3. **Assert** - add `--expect`, `--expect-text`, `--absent`, or `--eval` so the run fails loudly when behaviour regresses. Prefer assertions over eyeballing for anything you will touch twice.
4. **Edit** the `*.user.js`, re-run, compare.
5. **Lint** with `pnpm lint` before calling it done (see the repo AGENTS.md).

## Modes

**Local fixture** - iterate on DOM logic without network noise:

```bash
uv run .../run.py scripts/foo.user.js /page.html --serve _scratch/fixture --expect "#foo-bar"
```

`--serve DIR` starts a static server on a free port and turns paths into URLs; keep fixtures in `_scratch/`.

**Live site** - verify against the real thing, including anti-bot behaviour:

```bash
uv run .../run.py scripts/hn-tweaks.user.js https://news.ycombinator.com --wait 3000 --shot hn
```

`--humanize` adds human-like mouse movement; `--color-scheme dark` flips `prefers-color-scheme` for theme scripts; `--mobile` gives a phone viewport with touch and 2x scaling.

**Live mobile sites / bot blocks** - keep the browser and execute JavaScript, but route HTTP through curl_cffi's impersonating transport. Chromium adds real mobile emulation and an Android UA when `--mobile` is set:

```bash
CERTUTIL=$(nix build nixpkgs#nssTools --no-link --print-out-paths)/bin/certutil
CHROMIUM=$(nix build nixpkgs#chromium --no-link --print-out-paths)/bin/chromium
uv run run.py script.user.js https://www.reddit.com/r/selfhosted/ \
  --network cffi --browser chromium --mobile \
  --executable "$CHROMIUM" --certutil "$CERTUTIL" \
  --wait 3000 --shot reddit-mobile --expect 'shreddit-post'
```

This starts `cffi_proxy.py`, trusts its temporary CA only in a disposable browser profile, fails closed on native upstream connections, and writes `proxy-network.json` beside the screenshots. Camoufox works with `--network cffi` too, but it has no mobile identity, so use Chromium when the site's mobile layout matters. `--proxy-profile`/`--proxy-headers` override the transport identity; `--user-agent` overrides the UA.

`cffi_proxy.py` prints one JSON startup line and can also be used standalone while debugging another browser. It buffers finite HTTP responses only; WebSockets and SSE return 501.

**Scripted interactions** - for anything requiring clicks, typing, or multi-step flows:

```bash
uv run .../run.py scripts/foo.user.js https://example.com --steps _scratch/steps.json
```

`--steps` takes a JSON array; the runner prints the full action list with `--help`. Cover `goto`, `click`, `fill`, `press`, `scroll`, `waitFor`, `wait`, `eval`, `shot`, `expect`, `expectText`, `absent`, and `callMenu`.

## Verifying a specific claim

Two habits that make results trustworthy:

- **Assert the mechanism, not just the absence of errors.** A script that silently no-ops looks identical to a healthy one. Check for the element, attribute, or style it is supposed to create.
- **Prove the negative.** To confirm a script leaves a site alone (e.g. a redirect that should not fire on a non-target URL), use `--absent` on the thing a bug would add.

Useful probes:

```bash
# Confirm the cffi path and inspect its trace
--eval "location.href" --json   # report URLs redact challenge tokens
```

```bash
# What did the script register and inject?
--eval "Object.keys(window.__US_MENUS__ || {})"
--eval "document.querySelectorAll('style').length"
--eval "typeof GM.setValue"

# Did it touch the DOM the way I expect?
--expect "#injected-thing" --expect-text "#status=enabled"
```

`--json` emits a structured report (console, page errors, failed requests, results, failures, storage path) when the output needs parsing.

## Exercising GM_* APIs

The runner provides a shim implementing the GM surface these scripts use: `GM.getValue`/`setValue`/`deleteValue`/`listValues` and the legacy `GM_getValue`/`GM_setValue`, `GM_addStyle`/`GM.addStyle`, `GM.registerMenuCommand`/`unregisterMenuCommand`, `GM.xmlHttpRequest` (both spellings), `GM.openInTab`, `GM_info`, and `unsafeWindow`.

- **Storage** persists to `--storage FILE` (default `<out>/storage.json`) and seeds with `--set KEY=VALUE`, so multi-run state is testable.
- **Cross-origin requests** run through Python, so CORS does not apply - the same reason scripts use `GM_xmlhttpRequest`.
- **Menu commands** are invocable with `{"action": "callMenu", "name": "Enable"}`; the runner reports every menu the script registered.

`@require` entries are fetched and injected before the script body; `@match`/`@include`, `@run-at`, and `@noframes` are honoured.

## Constraints worth knowing

These are properties of the harness, not bugs to work around:

- The script runs in the **page world**, so `unsafeWindow === window` and script globals are visible to page code. Violentmonkey's sandboxing (`@inject-into content`, `@grant none` isolation) is not reproduced.
- `--network cffi` needs `certutil` from NSS tools; without it, use direct mode or install NSS tools. Camoufox's bundled NSS workaround is intentionally not duplicated here.
- Browser jobs still need a working browser. On NixOS use the wrapped Chromium path; a raw Playwright download may lack shared libraries.
- `GM.openInTab` and `GM.notification` are inert; the run reports the attempted URL instead. Redirect scripts are verified by the navigation they cause.
- Camoufox draws desktop identities only, so `--mobile` changes viewport, touch, and scaling - not the UA. Do not conclude a script passed mobile-detection logic from this alone.
- `moz-extension://` pages cannot be loaded under Playwright, which is why this harness drives the userscript directly instead of through Violentmonkey.

## Creating a new userscript

Follow the repo's one-file rule: new script means a new `scripts/name.user.js` with a complete `==UserScript==` header, ASCII-only, no shared modules.

1. Write the script with the metadata block and the logic.
2. Run it with a fixture that reproduces the DOM shape it targets (`--serve`) before pointing at the live site - faster and deterministic.
3. Confirm the live site, then screenshot for the record.
4. `pnpm lint`.

For general skill-authoring conventions (frontmatter rules, layout, when to split reference docs out of `SKILL.md`), see the `create-skill` skill.

## Reporting results

State what you observed, not that it "should work": the assertion that passed, the screenshot path, the console error that disappeared. Include assumptions, autonomous decisions, and compromises per the project AGENTS.md task-end report.
