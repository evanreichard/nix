# /// script
# requires-python = ">=3.12,<3.14"
# dependencies = ["mitmproxy==12.3.1", "curl_cffi==0.17.0"]
# ///
"""Loopback HTTPS proxy that sends all HTTP upstream traffic through curl_cffi.

The browser keeps rendering and executing JavaScript. Start it from run.py, or
standalone while developing: it prints one JSON line (proxy URL and CA path),
then serves until SIGINT/SIGTERM.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import re
import signal
import sys
import tempfile
import time
from collections import Counter, deque
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from curl_cffi import CurlHttpVersion, CurlOpt
from curl_cffi.requests import AsyncSession
from mitmproxy import http
from mitmproxy.options import Options
from mitmproxy.tools.dump import DumpMaster

HOP_HEADERS = {
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
    "proxy-connection", "te", "trailer", "transfer-encoding", "upgrade", "content-length",
}
PROFILE_HEADERS = {
    "user-agent", "accept-language", "accept-encoding",
    "sec-ch-ua", "sec-ch-ua-mobile", "sec-ch-ua-platform",
}
REDACT_KEYS = {"solution", "jsc_token", "token", "jsc_orig_r", "sig", "signature"}


def public_url(value: str) -> str:
    parts = urlsplit(value)
    query = [
        (key, value if key in {"js_challenge", "sort", "t", "limit"} else "[redacted]")
        for key, value in parse_qsl(parts.query)
        if key not in REDACT_KEYS
    ]
    return urlunsplit((parts.scheme, parts.netloc, parts.path, urlencode(query), ""))


def filtered_headers(items, *, response=False, metadata_only=False, profile=False):
    items = list(items)
    excluded = HOP_HEADERS | {
        part.strip().lower()
        for key, value in items if key.lower() == "connection"
        for part in value.split(",")
    }
    if response:
        # Decoded Bodies - curl_cffi decompresses; Alt-Svc could bypass this proxy with QUIC.
        excluded.add("alt-svc")
        if metadata_only:
            excluded.discard("content-length")
        else:
            excluded.add("content-encoding")
    else:
        excluded.add("host")
        if profile:
            excluded |= PROFILE_HEADERS
        cookies = [value for key, value in items if key.lower() == "cookie"]
        if cookies:
            items = [
                (key, value) for key, value in items if key.lower() != "cookie"
            ] + [("cookie", "; ".join(cookies))]
    return [(key.lower(), value) for key, value in items if key.lower() not in excluded]


class CurlTransport:
    def __init__(self, session: AsyncSession, args: argparse.Namespace):
        self.session = session
        self.args = args
        self.ready = asyncio.Event()
        self.trace: deque[dict] = deque(maxlen=args.trace_limit)
        self.native: deque[dict] = deque(maxlen=128)
        self.errors: deque[dict] = deque(maxlen=128)
        self.requests = 0
        self.forwarded = 0
        self.native_total = 0
        self.errors_total = 0
        self.profile_headers = args.headers == "impersonate"

    def running(self):
        self.ready.set()

    def server_connect(self, data):
        # Fail Closed - No native mitmproxy upstream connection may escape curl_cffi.
        self.native_total += 1
        self.native.append({"host": data.server.address[0], "port": data.server.address[1]})
        data.server.error = "Native upstream connections are disabled; curl_cffi owns transport"

    async def request(self, flow: http.HTTPFlow):
        request = flow.request
        self.requests += 1
        entry = {
            "url": public_url(request.pretty_url),
            "method": request.method,
            "destination": request.headers.get("sec-fetch-dest", ""),
        }
        self.trace.append(entry)
        started = time.monotonic()
        if request.headers.get("upgrade", "").lower() == "websocket":
            flow.response = http.Response.make(
                501, b"This proxy does not relay WebSockets.\n", {"content-type": "text/plain"}
            )
            entry.update(status=501, unsupported="websocket")
            return
        if "text/event-stream" in request.headers.get("accept", "").lower():
            flow.response = http.Response.make(
                501, b"This proxy buffers finite HTTP responses, not SSE.\n", {"content-type": "text/plain"}
            )
            entry.update(status=501, unsupported="event-stream")
            return
        try:
            headers = filtered_headers(
                request.headers.items(multi=True), profile=self.profile_headers
            )
            response = await self.session.request(
                request.method,
                request.pretty_url,
                headers=headers,
                data=request.raw_content,
                allow_redirects=False,
                timeout=self.args.request_timeout,
                discard_cookies=True,
                default_headers=self.profile_headers,
            )
            metadata_only = request.method == "HEAD" or response.status_code == 304
            entry.update(
                status=response.status_code,
                bytes=len(response.content),
                seconds=round(time.monotonic() - started, 3),
                upstream_http=CurlHttpVersion(response.http_version).name,
            )
            forwarded = filtered_headers(
                response.headers.multi_items(), response=True, metadata_only=metadata_only
            )
            flow.response = http.Response.make(response.status_code, b"")
            flow.response.headers = http.Headers(
                [(key.encode("ascii"), value.encode("latin-1")) for key, value in forwarded]
            )
            flow.response.raw_content = (
                b"" if metadata_only or response.status_code == 204 else response.content
            )
            if not metadata_only and response.status_code != 204:
                flow.response.headers["content-length"] = str(len(response.content))
            entry["forwarded"] = True
            self.forwarded += 1
        except Exception as error:
            self.errors_total += 1
            entry.update(status=502, error=f"{type(error).__name__}: {error}"[:300])
            self.errors.append({"url": entry["url"], "error": entry["error"]})
            flow.response = http.Response.make(
                502, b"curl_cffi upstream request failed; see the proxy trace.\n",
                {"content-type": "text/plain"},
            )

    def summary(self) -> dict:
        return {
            "requests": self.requests,
            "forwarded": self.forwarded,
            "http_statuses": dict(Counter(item.get("status") for item in self.trace)),
            "upstream_http": dict(Counter(item.get("upstream_http") for item in self.trace if "upstream_http" in item)),
            "unsupported": [item for item in self.trace if "unsupported" in item],
            "native_upstream_attempts_total": self.native_total,
            "native_upstream_attempts": list(self.native),
            "errors_total": self.errors_total,
            "errors": list(self.errors),
            "retained_requests": len(self.trace),
        }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=["chrome152", "firefox155"], default="chrome152")
    parser.add_argument("--headers", choices=["browser", "impersonate"], default="impersonate")
    parser.add_argument("--request-timeout", type=int, default=25)
    parser.add_argument("--max-bytes", type=int, default=32 * 1024 * 1024)
    parser.add_argument("--trace-limit", type=int, default=5000)
    parser.add_argument("--trace", metavar="FILE", help="write a JSON network trace on shutdown")
    args = parser.parse_args(argv)
    if min(args.request_timeout, args.max_bytes, args.trace_limit) <= 0:
        parser.error("timeouts and limits must be positive")
    return args


async def run(args: argparse.Namespace) -> int:
    temporary = tempfile.TemporaryDirectory(prefix="userscript-cffi-")
    master = None
    session = None
    task = None
    try:
        options = Options(
            listen_host="127.0.0.1", listen_port=0, confdir=temporary.name,
            upstream_cert=False, http2=True,
        )
        master = DumpMaster(options, with_termlog=False, with_dumper=False)
        master.options.update(
            connection_strategy="lazy", body_size_limit=f"{args.max_bytes}b", rawtcp=False
        )
        session = AsyncSession(
            impersonate=args.profile, discard_cookies=True, max_clients=16,
            trust_env=False, curl_options={CurlOpt.MAXFILESIZE_LARGE: args.max_bytes},
        )
        transport = CurlTransport(session, args)
        master.addons.add(transport)
        task = asyncio.create_task(master.run(), name="userscript-cffi-proxy")
        ready = asyncio.create_task(transport.ready.wait())
        done, _ = await asyncio.wait({task, ready}, timeout=20, return_when=asyncio.FIRST_COMPLETED)
        ready.cancel()
        await asyncio.gather(ready, return_exceptions=True)
        if task in done:
            await task
            raise RuntimeError("proxy exited during startup")
        if not transport.ready.is_set():
            raise TimeoutError("proxy did not start in 20 seconds")
        addresses = master.addons.get("proxyserver").listen_addrs()
        if not addresses:
            raise RuntimeError("proxy has no listening socket")
        proxy_url = f"http://127.0.0.1:{addresses[0][1]}"
        print(json.dumps({
            "proxy": proxy_url,
            "ca": str(Path(temporary.name) / "mitmproxy-ca-cert.pem"),
            "profile": args.profile,
            "headers": args.headers,
        }), flush=True)

        stop = asyncio.Event()
        loop = asyncio.get_running_loop()
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(sig, stop.set)
        try:
            await stop.wait()
        finally:
            for sig in (signal.SIGINT, signal.SIGTERM):
                loop.remove_signal_handler(sig)
        summary = transport.summary()
        if args.trace:
            Path(args.trace).write_text(json.dumps(summary, indent=2) + "\n")
        return 0 if summary["native_upstream_attempts_total"] == 0 else 1
    finally:
        if master is not None:
            server = master.addons.get("proxyserver")
            if server:
                try:
                    await asyncio.wait_for(server.servers.update([]), timeout=2)
                except Exception:
                    pass
            master.shutdown()
        if task is not None:
            try:
                await asyncio.wait_for(task, timeout=5)
            except (asyncio.TimeoutError, asyncio.CancelledError):
                task.cancel()
                await asyncio.gather(task, return_exceptions=True)
        if session is not None:
            await session.close()
        temporary.cleanup()


def main() -> int:
    args = parse_args(sys.argv[1:])
    try:
        return asyncio.run(run(args))
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main())
