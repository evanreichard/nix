# /// script
# requires-python = ">=3.12,<3.14"
# dependencies = ["camoufox", "certifi", "curl_cffi==0.17.0", "mitmproxy==12.3.1", "playwright==1.62.0"]
# ///
"""Run a userscript against real pages in Camoufox or Chromium.

The userscript is injected into the page world through a Playwright init script,
so it behaves like a real userscript without needing Violentmonkey: GM_* calls are
served by a shim whose storage and cross-origin requests are handled here in Python.

Run it with uv, which resolves the dependency header above:

    uv run run.py ../../scripts/hn-tweaks.user.js https://news.ycombinator.com
    uv run run.py script.user.js https://www.reddit.com/r/selfhosted/ \
      --network cffi --browser chromium --mobile

Exit codes: 0 success, 1 assertion or page-error failure, 2 usage/load failure.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import selectors
import shutil
import ssl
import subprocess
import sys
import tempfile
import threading
import traceback
import urllib.error
import urllib.parse
import urllib.request
from contextlib import ExitStack
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent
SHIM = SKILL_DIR / "gm_shim.js"
PROXY = SKILL_DIR / "cffi_proxy.py"
ANDROID_UA = (
    "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36"
)
META_RE = re.compile(r"//\s*==UserScript==(.*?)//\s*==/UserScript==", re.S)
TAG_RE = re.compile(r"//\s*@([\w:-]+)\s*(.*)")


class UsageError(Exception):
    pass


def redact_url(value: str) -> str:
    """Hide challenge/auth tokens while keeping the route useful in reports."""
    parts = urllib.parse.urlsplit(value)
    hidden = {"solution", "jsc_token", "token", "jsc_orig_r", "sig", "signature"}
    query = [
        (key, value if key not in hidden else "[redacted]")
        for key, value in urllib.parse.parse_qsl(parts.query)
    ]
    return urllib.parse.urlunsplit(
        (parts.scheme, parts.netloc, parts.path, urllib.parse.urlencode(query), "")
    )


def parse_metadata(source: str) -> dict[str, list[str]]:
    """Collect the ==UserScript== header into a name -> list-of-values map."""
    match = META_RE.search(source)
    if not match:
        raise UsageError("no ==UserScript== metadata block found")
    meta: dict[str, list[str]] = {}
    for line in match.group(1).splitlines():
        tag = TAG_RE.match(line.strip())
        if not tag:
            continue
        meta.setdefault(tag.group(1), []).append(tag.group(2).strip())
    return meta


def strip_metadata(source: str) -> str:
    return META_RE.sub("", source, count=1)


def ssl_context() -> ssl.SSLContext:
    """NixOS Python ships no CA bundle; prefer certifi when it is available."""
    try:
        import certifi

        return ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        return ssl.create_default_context()


def fetch_requires(requires: list[str], base_dir: Path) -> list[tuple[str, str]]:
    """Resolve @require entries to source text. Supports http(s) and local files."""
    loaded: list[tuple[str, str]] = []
    for entry in requires:
        url = entry.split()[0]  # drop optional #sha256= fragment
        try:
            if url.startswith(("http://", "https://")):
                req = urllib.request.Request(url, headers={"User-Agent": "userscript-test"})
                with urllib.request.urlopen(req, timeout=30, context=ssl_context()) as resp:
                    loaded.append((url, resp.read().decode("utf-8", "replace")))
            else:
                path = Path(url)
                if not path.is_absolute():
                    path = (base_dir / path).resolve()
                loaded.append((url, path.read_text(encoding="utf-8")))
        except (urllib.error.URLError, OSError) as exc:
            print(f"[warn] @require {url} failed: {exc}", file=sys.stderr)
    return loaded


class Storage:
    """JSON-backed GM storage so runs are repeatable and state is inspectable."""

    def __init__(self, path: Path):
        self.path = path
        self.data: dict[str, object] = {}
        if path.exists():
            try:
                self.data = json.loads(path.read_text())
            except json.JSONDecodeError:
                print(f"[warn] ignoring corrupt storage {path}", file=sys.stderr)
        self.lock = threading.Lock()

    def get(self, key: str) -> tuple[bool, object]:
        with self.lock:
            return (key in self.data, self.data.get(key))

    def set(self, key: str, value: object) -> None:
        with self.lock:
            self.data[key] = value
            self._flush()

    def delete(self, key: str) -> None:
        with self.lock:
            self.data.pop(key, None)
            self._flush()

    def _flush(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps(self.data, indent=2, sort_keys=True))


def perform_xhr(payload: dict) -> dict:
    """Cross-origin request on the script's behalf. Python is not bound by CORS."""
    url = payload.get("url")
    if not url:
        return {"error": "no url"}
    method = (payload.get("method") or "GET").upper()
    headers = payload.get("headers") or {}
    data = payload.get("data")
    body = data.encode() if isinstance(data, str) else None
    if body is not None and method == "GET":
        method = "POST"  # A body on GET is a script bug; send it rather than drop it.
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=payload.get("timeout") or 30, context=ssl_context()) as resp:
            raw = resp.read()
            return {
                "status": resp.status,
                "statusText": resp.reason or "",
                "url": resp.geturl(),
                "headers": "\r\n".join(f"{k}: {v}" for k, v in resp.headers.items()),
                "text": raw.decode("utf-8", "replace"),
            }
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        return {
            "status": exc.code,
            "statusText": exc.reason or "",
            "url": url,
            "headers": "",
            "text": raw,
        }
    except (urllib.error.URLError, OSError) as exc:
        return {"error": str(exc)}


def build_init_script(
    body: str,
    meta: dict[str, list[str]],
    requires: list[tuple[str, str]],
    storage_snapshot: dict[str, object],
    run_at: str,
) -> str:
    """Compose cfg + shim + @require libraries + userscript body into one init script."""
    info = {
        "script": {
            "name": (meta.get("name") or ["userscript"])[0],
            "namespace": (meta.get("namespace") or [""])[0],
            "version": (meta.get("version") or ["0"])[0],
            "description": (meta.get("description") or [""])[0],
            "matches": meta.get("match", []) + meta.get("include", []),
        }
    }
    cfg = {
        "info": info,
        "matches": meta.get("match", []),
        "includes": meta.get("include", []),
        "storage": storage_snapshot,
    }
    requires_js = "\n".join(
        f"try {{\n{src}\n}} catch (e) {{ console.error('[userscript-test] @require {url} failed', e); }}"
        for url, src in requires
    )

    # @noframes: skip sub-frames, matching the directive's intent.
    frame_guard = "if (window.top !== window.self) return;" if meta.get("noframes") else ""

    runner = (
        f"var usBody = function () {{\n  try {{\n{body}\n  }} catch (e) {{\n"
        "    console.error('[userscript-test] userscript threw: ' + (e && e.message ? e.message : e));"
        "    console.error(String(e && e.stack ? e.stack : ''));\n  }\n};\n"
    )

    if run_at == "document-start":
        schedule = "usBody();"
    elif run_at == "document-end":
        schedule = (
            "if (document.readyState === 'loading') "
            "document.addEventListener('DOMContentLoaded', usBody, { once: true }); else usBody();"
        )
    else:
        schedule = (
            "if (document.readyState === 'complete') usBody(); "
            "else window.addEventListener('load', usBody, { once: true });"
        )

    return f"""(function () {{
  window.__US_CFG__ = {json.dumps(cfg)};
}})();
{SHIM.read_text()}
(function () {{
  {frame_guard}
  if (!window.__US_MATCHES__(location.href)) return;
  {requires_js}
  {runner}
  {schedule}
}})();"""


def normalise_run_at(meta: dict[str, list[str]], override: str | None) -> str:
    if override:
        return override
    raw = (meta.get("run-at") or ["document-idle"])[0].lower()
    mapping = {
        "document-start": "document-start",
        "document-body": "document-start",
        "document-end": "document-end",
        "document-idle": "document-idle",
    }
    return mapping.get(raw, "document-idle")


def url_matches_header(meta: dict[str, list[str]], url: str) -> bool:
    """Report whether the final URL matches the script's @match/@include list."""
    patterns = meta.get("match", []) + meta.get("include", [])
    if not patterns:
        return True
    for pattern in patterns:
        try:
            if pattern.startswith("/") and pattern.rfind("/") > 0:
                end = pattern.rfind("/")
                if re.search(pattern[1:end], url):
                    return True
            elif re.match("^" + re.escape(pattern).replace(r"\*", ".*") + "$", url):
                return True
        except re.error:
            continue
    return False


STEPS_HELP = """Available step actions:
  {"action": "goto", "url": "..."}
  {"action": "reload"}
  {"action": "click", "selector": "..."}
  {"action": "fill", "selector": "...", "value": "..."}
  {"action": "press", "selector": "...", "key": "Enter"}
  {"action": "scroll", "selector": "...", "optional": true} | {"action": "scroll", "y": 1200}
  {"action": "waitFor", "selector": "...", "timeout": 5000}
  {"action": "wait", "ms": 500}
  {"action": "eval", "js": "document.title", "label": "title"}
  {"action": "shot", "name": "after-click"}
  {"action": "expect", "selector": "...", "count": 1}
  {"action": "expectText", "selector": "...", "text": "substring"}
  {"action": "absent", "selector": "..."}
  {"action": "callMenu", "name": "menu name substring"}
"""


def run_steps(page, steps: list[dict], out_dir: Path, results: list[str], failures: list[str]) -> None:
    for index, step in enumerate(steps, 1):
        action = step.get("action")
        optional = bool(step.get("optional"))
        try:
            if action == "goto":
                page.goto(step["url"], wait_until=step.get("waitUntil", "domcontentloaded"))
            elif action == "reload":
                page.reload(wait_until=step.get("waitUntil", "domcontentloaded"))
            elif action == "click":
                page.click(step["selector"], timeout=step.get("timeout", 5000))
            elif action == "fill":
                page.fill(step["selector"], str(step.get("value", "")), timeout=step.get("timeout", 5000))
            elif action == "press":
                page.press(step["selector"], step["key"], timeout=step.get("timeout", 5000))
            elif action == "scroll":
                if step.get("selector"):
                    page.locator(step["selector"]).first.scroll_into_view_if_needed(timeout=step.get("timeout", 5000))
                else:
                    page.mouse.wheel(0, int(step.get("y", 1000)))
            elif action == "waitFor":
                page.wait_for_selector(step["selector"], timeout=step.get("timeout", 5000))
            elif action == "wait":
                page.wait_for_timeout(int(step.get("ms", 500)))
            elif action == "eval":
                value = page.evaluate(step["js"]) if "js" in step else page.evaluate(step["expr"])
                results.append(f"eval[{step.get('label', index)}]: {json.dumps(value, default=str)[:400]}")
            elif action == "shot":
                path = out_dir / f"{step.get('name', f'step-{index}')}.png"
                page.screenshot(path=str(path), full_page=bool(step.get("fullPage")))
                results.append(f"screenshot: {path}")
            elif action == "expect":
                count = page.locator(step["selector"]).count()
                want = step.get("count", 1)
                if count < (want if isinstance(want, int) else 1):
                    failures.append(f"expect {step['selector']}: found {count}, wanted >={want}")
                else:
                    results.append(f"expect ok: {step['selector']} ({count})")
            elif action == "expectText":
                actual = page.locator(step["selector"]).first.inner_text(timeout=step.get("timeout", 5000))
                if step["text"] not in actual:
                    failures.append(f"expectText {step['selector']}: {step['text']!r} not in {actual[:200]!r}")
                else:
                    results.append(f"expectText ok: {step['selector']}")
            elif action == "absent":
                count = page.locator(step["selector"]).count()
                if count:
                    failures.append(f"absent {step['selector']}: found {count}")
                else:
                    results.append(f"absent ok: {step['selector']}")
            elif action == "callMenu":
                needle = step["name"]
                invoked = page.evaluate(
                    """(needle) => {
                        const menus = window.__US_MENUS__ || {};
                        const hit = Object.values(menus).find((m) => m.name && m.name.includes(needle));
                        if (!hit) return null;
                        hit.fn();
                        return hit.name;
                    }""",
                    needle,
                )
                if invoked is None:
                    failures.append(f"callMenu: no menu matching {needle!r}")
                else:
                    results.append(f"callMenu ok: {invoked}")
            else:
                failures.append(f"step {index}: unknown action {action!r}")
        except Exception as exc:
            detail = f"step {index} ({action}): {type(exc).__name__}: {str(exc).splitlines()[0][:200]}"
            if optional:
                results.append(f"skipped optional {detail}")
            else:
                failures.append(detail)


class CffiProxy:
    """Start cffi_proxy.py and expose its URL, CA path, and trace file."""

    def __init__(self, args: argparse.Namespace, out_dir: Path):
        self.args = args
        self.out_dir = out_dir
        self.process: subprocess.Popen | None = None
        self.url = ""
        self.ca = Path()
        self.trace = out_dir / "proxy-network.json"

    def __enter__(self):
        trace = self.trace
        trace.unlink(missing_ok=True)
        command = [
            sys.executable, str(PROXY),
            "--profile", self.args.proxy_profile,
            "--headers", self.args.proxy_headers,
            "--request-timeout", str(max(1, self.args.wait // 1000 + 20)),
            "--trace", str(trace),
        ]
        self.process = subprocess.Popen(
            command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1
        )
        selector = selectors.DefaultSelector()
        assert self.process.stdout is not None
        selector.register(self.process.stdout, selectors.EVENT_READ)
        try:
            if not selector.select(timeout=45):
                raise UsageError(
                    "cffi proxy did not start in 45s; run cffi_proxy.py directly to see the error"
                )
            line = self.process.stdout.readline()
            startup = json.loads(line)
            self.url = startup["proxy"]
            self.ca = Path(startup["ca"])
        except (json.JSONDecodeError, KeyError, OSError) as exc:
            self.__exit__(None, None, None)
            raise UsageError(f"cffi proxy failed to start: {exc}") from exc
        finally:
            selector.close()
        return self

    def __exit__(self, *_exc):
        if not self.process:
            return
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=5)
        if self.process.stdout:
            self.process.stdout.close()
        self.process = None


def trust_proxy_ca(certutil: str, database: Path, ca: Path) -> None:
    database.mkdir(parents=True, exist_ok=True, mode=0o700)
    for command in (
        [certutil, "-N", "--empty-password", "-d", f"sql:{database}"],
        [certutil, "-A", "-n", "userscript-test", "-t", "C,,", "-i", str(ca), "-d", f"sql:{database}"],
    ):
        result = subprocess.run(command, capture_output=True, text=True, timeout=20)
        if result.returncode != 0:
            raise UsageError(f"certutil failed: {result.stderr.strip()[:300]}")


def certutil_path(explicit: str | None) -> str:
    found = explicit or shutil.which("certutil")
    if not found:
        raise UsageError(
            "--network cffi needs NSS certutil for scoped browser trust. "
            "Install NSS tools (e.g. nix shell nixpkgs#nssTools) or pass --certutil."
        )
    return found


def serve(directory: Path, port: int) -> ThreadingHTTPServer:
    class Quiet(SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(directory), **kwargs)

        def log_message(self, *args):  # noqa: A003 - stdlib hook name
            pass

    server = ThreadingHTTPServer(("127.0.0.1", port), Quiet)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a userscript in Camoufox and report its behaviour.",
        epilog=STEPS_HELP,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("script", help="path to the *.user.js file")
    parser.add_argument("urls", nargs="*", help="page(s) to load")
    parser.add_argument(
        "--network", choices=["direct", "cffi"], default="direct",
        help="direct browser networking (default) or a loopback HTTPS proxy backed by curl_cffi",
    )
    parser.add_argument(
        "--browser", choices=["camoufox", "chromium"], default="camoufox",
        help="browser engine (Camoufox default; Chromium supports real mobile emulation)",
    )
    parser.add_argument("--executable", help="browser executable (Nix-wrapped Chromium is recommended)")
    parser.add_argument("--user-agent", help="override User-Agent (mobile Chromium defaults to Android)")
    parser.add_argument("--certutil", help="NSS certutil used to trust the cffi proxy CA")
    parser.add_argument(
        "--proxy-profile", choices=["chrome152", "firefox155"],
        help="curl_cffi impersonation profile (defaults from --browser)",
    )
    parser.add_argument(
        "--proxy-headers", choices=["browser", "impersonate"],
        help="forward browser headers or let curl_cffi supply impersonated headers",
    )
    parser.add_argument("--serve", metavar="DIR", help="serve DIR over HTTP; URLs become paths")
    parser.add_argument("--port", type=int, default=0, help="port for --serve (0 picks a free one)")
    parser.add_argument("--steps", metavar="FILE", help="JSON array of interaction steps")
    parser.add_argument("--out", metavar="DIR", help="screenshots/artifacts directory")
    parser.add_argument("--shot", metavar="NAME", help="screenshot name (default: shot)")
    parser.add_argument("--full-page", action="store_true", help="full-page screenshots")
    parser.add_argument("--wait", type=int, default=1500, metavar="MS", help="settle time after load")
    parser.add_argument("--viewport", default="1440x900", metavar="WxH")
    parser.add_argument("--mobile", action="store_true", help="phone viewport, touch, 2x scale factor")
    parser.add_argument(
        "--color-scheme",
        choices=["light", "dark", "no-preference"],
        default="light",
        help="emulated prefers-color-scheme",
    )
    parser.add_argument("--locale", default="en-US", help="navigator.language / Accept-Language")
    parser.add_argument("--timezone", metavar="TZ", help="emulated timezone, e.g. America/New_York")
    parser.add_argument("--geolocation", metavar="LAT,LON", help="grant and return this geolocation")
    parser.add_argument("--run-at", choices=["document-start", "document-end", "document-idle"])
    parser.add_argument("--storage", metavar="FILE", help="GM storage JSON (persisted between runs)")
    parser.add_argument("--set", action="append", default=[], metavar="KEY=VALUE", help="seed GM storage")
    parser.add_argument(
        "--eval", dest="evals", action="append", default=[], metavar="JS", help="evaluate JS after load"
    )
    parser.add_argument("--expect", action="append", default=[], metavar="SELECTOR", help="assert selector exists")
    parser.add_argument(
        "--absent", action="append", default=[], metavar="SELECTOR", help="assert selector is gone"
    )
    parser.add_argument("--expect-text", action="append", default=[], metavar="SEL=TEXT")
    parser.add_argument("--console", choices=["all", "log", "errors", "none"], default="all")
    parser.add_argument(
        "--verbose-warnings",
        action="store_true",
        help="include browser-internal warnings (CSP, quirks mode) in console output",
    )
    parser.add_argument("--allow-page-errors", action="store_true", help="do not fail on page errors")
    parser.add_argument("--humanize", action="store_true", help="camoufox human-like mouse movement")
    parser.add_argument("--json", action="store_true", help="emit a JSON report")
    parser.add_argument("--dump-html", metavar="FILE", help="write final page HTML")
    return parser.parse_args(argv)


def navigate(page, url: str, wait_until: str, results: list[str], failures: list[str]) -> None:
    """Navigate, tolerating the interruption a redirecting userscript causes."""
    try:
        page.goto(url, wait_until=wait_until, timeout=45000)
    except Exception as exc:
        message = str(exc)
        if "interrupted by another navigation" in message or "NS_BINDING_ABORTED" in message:
            results.append(f"navigation interrupted (script redirected away from {url})")
        elif "NS_ERROR_ABORT" in message or "Target page" in message:
            results.append(f"navigation aborted by the script ({url})")
        else:
            failures.append(f"goto {url}: {type(exc).__name__}: {message.splitlines()[0][:180]}")


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    script_path = Path(args.script).expanduser()
    if not script_path.is_file():
        raise UsageError(f"script not found: {script_path}")
    source = script_path.read_text(encoding="utf-8")
    meta = parse_metadata(source)
    body = strip_metadata(source)
    run_at = normalise_run_at(meta, args.run_at)

    out_dir = Path(args.out) if args.out else Path("_scratch/shots") / script_path.stem
    out_dir.mkdir(parents=True, exist_ok=True)

    storage_path = Path(args.storage) if args.storage else out_dir / "storage.json"
    storage = Storage(storage_path)
    for pair in args.set:
        if "=" not in pair:
            raise UsageError(f"--set expects KEY=VALUE, got {pair!r}")
        key, value = pair.split("=", 1)
        storage.set(key, value)

    requires = fetch_requires(meta.get("require", []), script_path.parent)
    init_script = build_init_script(body, meta, requires, storage.data, run_at)

    urls = list(args.urls)
    server = None
    if args.serve:
        serve_dir = Path(args.serve).expanduser().resolve()
        if not serve_dir.is_dir():
            raise UsageError(f"--serve directory not found: {serve_dir}")
        server = serve(serve_dir, args.port)
        base = f"http://127.0.0.1:{server.server_address[1]}"
        urls = [u if u.startswith(("http://", "https://")) else f"{base}/{u.lstrip('/')}" for u in urls]
    if not urls and not args.steps:
        raise UsageError("provide at least one URL, or use --serve plus a path")

    width, height = (int(x) for x in args.viewport.lower().split("x"))
    viewport = {"width": 375, "height": 812} if args.mobile else {"width": width, "height": height}

    console_lines: list[str] = []
    page_errors: list[str] = []
    failed_requests: list[str] = []
    results: list[str] = []
    failures: list[str] = []
    menus_seen: list[str] = []

    from camoufox.sync_api import Camoufox

    if args.proxy_profile is None:
        args.proxy_profile = "chrome152" if args.browser == "chromium" else "firefox155"
    if args.proxy_headers is None:
        args.proxy_headers = "impersonate" if args.browser == "chromium" else "browser"
    user_agent = args.user_agent or (ANDROID_UA if args.mobile and args.browser == "chromium" else None)
    certutil = certutil_path(args.certutil) if args.network == "cffi" else None

    try:
        with ExitStack() as stack:
            proxy = stack.enter_context(CffiProxy(args, out_dir)) if args.network == "cffi" else None

            if args.browser == "chromium":
                from playwright.sync_api import sync_playwright

                playwright = stack.enter_context(sync_playwright())
                executable = args.executable or playwright.chromium.executable_path
                launch = {
                    "headless": True,
                    "executable_path": executable,
                    "viewport": viewport,
                    "has_touch": args.mobile,
                    "device_scale_factor": 2 if args.mobile else 1,
                    "is_mobile": args.mobile,
                    "color_scheme": args.color_scheme,
                    "locale": args.locale,
                    "timezone_id": args.timezone or None,
                }
                if user_agent:
                    launch["user_agent"] = user_agent
                if proxy:
                    home = stack.enter_context(tempfile.TemporaryDirectory(prefix="userscript-cffi-browser-"))
                    assert certutil
                    trust_proxy_ca(certutil, Path(home) / ".pki" / "nssdb", proxy.ca)
                    context = playwright.chromium.launch_persistent_context(
                        str(Path(home) / "chromium-profile"),
                        proxy={"server": proxy.url, "bypass": "<-loopback>"},
                        env={
                            **os.environ, "HOME": home,
                            "XDG_CONFIG_HOME": str(Path(home) / ".config"),
                            "XDG_DATA_HOME": str(Path(home) / ".local" / "share"),
                        },
                        args=["--disable-quic"],
                        ignore_https_errors=False,
                        **launch,
                    )
                    stack.callback(context.close)
                else:
                    browser = playwright.chromium.launch(headless=True, executable_path=executable)
                    stack.callback(browser.close)
                    context = browser.new_context(**launch)
            else:
                camoufox_options = {
                    "headless": True,
                    "locale": [args.locale],
                    "humanize": args.humanize,
                    "exclude_addons": None,  # keep uBlock Origin: it is part of what Camoufox tests against
                }
                if proxy:
                    home = stack.enter_context(tempfile.TemporaryDirectory(prefix="userscript-cffi-browser-"))
                    profile = Path(home) / "firefox-profile"
                    assert certutil
                    trust_proxy_ca(certutil, profile, proxy.ca)
                    port = proxy.url.rsplit(":", 1)[-1]
                    prefs = {
                        "network.proxy.type": 1,
                        "network.proxy.http": "127.0.0.1",
                        "network.proxy.http_port": int(port),
                        "network.proxy.ssl": "127.0.0.1",
                        "network.proxy.ssl_port": int(port),
                        "network.proxy.no_proxies_on": "",
                        "network.proxy.allow_hijacking_localhost": True,
                        "network.http.http3.enable": False,
                    }
                    context = stack.enter_context(Camoufox(
                        persistent_context=True,
                        user_data_dir=str(profile),
                        proxy={"server": proxy.url, "bypass": "<-loopback>"},
                        firefox_user_prefs=prefs,
                        env={**os.environ, "HOME": home},
                        viewport=viewport,
                        ignore_https_errors=False,
                        **camoufox_options,
                    ))
                else:
                    browser = stack.enter_context(Camoufox(**camoufox_options))
                    context = browser.new_context(
                        viewport=viewport,
                        has_touch=args.mobile,
                        device_scale_factor=2 if args.mobile else 1,
                        # is_mobile is deliberately unset: Camoufox only draws desktop
                        # identities and ignores it, so it would warn and change nothing.
                        color_scheme=args.color_scheme,
                        locale=args.locale,
                        timezone_id=args.timezone or None,
                    )

            if user_agent and args.browser == "camoufox":
                context.set_extra_http_headers({"User-Agent": user_agent})
            if args.geolocation:
                lat, lon = (float(x) for x in args.geolocation.split(","))
                context.grant_permissions(["geolocation"])
                context.set_geolocation({"latitude": lat, "longitude": lon})

            def bridge(op: str, payload: dict) -> object:
                if op == "getValue":
                    found, value = storage.get(payload.get("key"))
                    return {"found": found, "value": value}
                if op == "setValue":
                    storage.set(payload.get("key"), payload.get("value"))
                    return {"ok": True}
                if op == "deleteValue":
                    storage.delete(payload.get("key"))
                    return {"ok": True}
                if op == "listValues":
                    return {"keys": sorted(storage.data)}
                if op == "xhr":
                    return perform_xhr(payload)
                if op == "menu":
                    menus_seen.append(payload.get("name", ""))
                    return {"ok": True}
                if op == "openInTab":
                    return {"ok": False, "reason": "openInTab is not emulated; inspect the URL instead"}
                return {"error": f"unknown bridge op {op}"}

            context.expose_binding("__us_bridge", lambda source, op, payload=None: bridge(op, payload or {}))
            context.add_init_script(init_script)

            page = context.new_page()
            # Browser-internal warnings about CSP, quirks mode, etc. drown out the
            # script's own logging; keep them behind --console all only.
            noisy = ("JavaScript Warning", "Feature Policy", "Layout was forced", "Quirks Mode")

            def on_console(message) -> None:
                if args.console == "none":
                    return
                if args.console == "errors" and message.type not in ("error",):
                    return
                if args.console == "log" and message.type not in ("log", "info", "debug"):
                    return
                text = message.text
                if any(marker in text for marker in noisy) and not args.verbose_warnings:
                    return
                console_lines.append(f"{message.type}: {text}")

            page.on("console", on_console)
            page.on("pageerror", lambda e: page_errors.append(str(e).splitlines()[0][:300]))
            page.on(
                "requestfailed",
                lambda r: (
                    failed_requests.append(f"{r.url[:120]} ({r.failure})")
                    if r.resource_type != "image"
                    else None
                ),
            )

            index = 0
            for url in urls:
                index += 1
                navigate(page, url, "domcontentloaded", results, failures)
                page.wait_for_timeout(args.wait)
                if index == 1 and not page.evaluate("window.__US_SHIM_READY__ === true"):
                    page_errors.append(
                        "GM shim did not initialise (init script likely threw before defining it)"
                    )
                name = f"{args.shot or 'shot'}-{index}" if len(urls) > 1 else (args.shot or "shot")
                path = out_dir / f"{name}.png"
                page.screenshot(path=str(path), full_page=args.full_page)
                results.append(f"screenshot: {path}")

            if args.steps:
                steps = json.loads(Path(args.steps).read_text())
                run_steps(page, steps, out_dir, results, failures)

            for expr in args.evals:
                value = page.evaluate(expr)
                results.append(f"eval[{expr[:40]}]: {json.dumps(value, default=str)[:400]}")
            for selector in args.expect:
                count = page.locator(selector).count()
                (results if count else failures).append(
                    f"expect {selector}: {count}" if count else f"expect {selector}: not found"
                )
            for selector in args.absent:
                count = page.locator(selector).count()
                (failures if count else results).append(
                    f"absent {selector}: found {count}" if count else f"absent {selector}: ok"
                )
            for pair in args.expect_text:
                selector, sep, text = pair.partition("=")
                if not sep:
                    failures.append(f"--expect-text expects SELECTOR=TEXT, got {pair!r}")
                    continue
                try:
                    actual = page.locator(selector).first.inner_text(timeout=5000)
                except Exception as exc:
                    failures.append(f"expectText {selector}: {type(exc).__name__} ({selector} not found?)")
                    continue
                if text in actual:
                    results.append(f"expectText {selector}: ok")
                else:
                    failures.append(f"expectText {selector}: {text!r} not in {actual[:200]!r}")

            if args.dump_html:
                Path(args.dump_html).write_text(page.content())

            final_url = page.url
            title = page.title()
            context.close()
    finally:
        if server is not None:
            server.shutdown()

    matched = url_matches_header(meta, final_url)

    if page_errors and not args.allow_page_errors:
        failures.extend(f"page error: {e}" for e in page_errors)

    proxy_trace = out_dir / "proxy-network.json"
    report = {
        "script": str(script_path),
        "network": args.network,
        "browser": args.browser,
        "proxyTrace": str(proxy_trace) if proxy_trace.exists() else None,
        "name": (meta.get("name") or ["?"])[0],
        "runAt": run_at,
        "grants": meta.get("grant", []),
        "url": redact_url(final_url),
        "title": title,
        "urlMatchedHeader": matched,
        "menuCommands": menus_seen,
        "console": console_lines,
        "pageErrors": page_errors,
        "failedRequests": failed_requests,
        "results": results,
        "failures": failures,
        "screenshots": sorted(str(p) for p in out_dir.glob("*.png")),
        "storage": str(storage_path),
    }

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(f"script   : {report['name']}  ({script_path})")
        print(f"run-at   : {run_at}   grants: {', '.join(report['grants']) or 'none'}")
        print(f"page     : {redact_url(final_url)}")
        print(f"title    : {title}")
        print(f"network  : {args.network}   browser: {args.browser}")
        if proxy_trace.exists():
            print(f"proxy    : {proxy_trace}")
        if not matched:
            print("note     : final URL does not match this script's @match/@include")
        if menus_seen:
            print(f"menus    : {', '.join(menus_seen)}")
        for line in results:
            print(f"  ok  {line}")
        for line in failures:
            print(f"  FAIL {line}")
        if args.console != "none" and console_lines:
            print("console:")
            for line in console_lines[:60]:
                print(f"  {line}")
            if len(console_lines) > 60:
                print(f"  ... {len(console_lines) - 60} more")
        if failed_requests:
            print("failed requests:")
            for line in failed_requests[:15]:
                print(f"  {line}")
        print(f"storage  : {storage_path}")

    if failures:
        print(f"\n{len(failures)} failure(s)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except UsageError as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(2)
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception:  # noqa: BLE001 - surface unexpected failures plainly
        traceback.print_exc()
        sys.exit(2)
