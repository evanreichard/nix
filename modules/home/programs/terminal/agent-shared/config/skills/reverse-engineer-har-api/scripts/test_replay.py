#!/usr/bin/env python3
"""Offline integration checks against a loopback HTTP server; no third-party API calls."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
from queue import Queue
import stat
import subprocess
import sys
import tempfile
import threading


def main():
    received = Queue()
    body = b'{"value":"private-body"}\n'

    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            payload = self.rfile.read(int(self.headers.get('Content-Length', '0')))
            received.put((dict(self.headers.items()), payload))
            response = b'{"ok":true}'
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(response)))
            self.end_headers()
            self.wfile.write(response)

        def log_message(self, *_):
            pass

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    script = Path(__file__).with_name('replay.py')
    try:
        with tempfile.TemporaryDirectory(prefix='test-', dir=script.parent.parent) as directory:
            root = Path(directory)
            har = root / 'capture with spaces.har'
            har.write_text(json.dumps({'log': {'entries': [{
                'request': {
                    'method': 'POST', 'url': f'http://127.0.0.1:{server.server_port}/prices?token=private-query',
                    'httpVersion': 'HTTP/1.1',
                    'headers': [{'name': name, 'value': value} for name, value in [
                        ('User-Agent', 'CapturedBrowser/1'), ('Accept', 'application/json'),
                        ('Accept-Language', 'en-US'), ('Accept-Encoding', 'gzip'),
                        ('Content-Type', 'application/json'), ('Cookie', 'session=private-cookie; guard=private-guard'),
                    ]],
                    'postData': {'text': body.decode(), 'mimeType': 'application/json'},
                },
                'response': {'status': 200, 'content': {'mimeType': 'application/json', 'size': 11}},
            }]}}))
            listing = subprocess.check_output([sys.executable, str(script), 'inspect', str(har)], text=True)
            assert 'private-query' not in listing and 'private-cookie' not in listing

            def run(*options):
                result = subprocess.run([sys.executable, str(script), 'replay', str(har), '0', '--out', str(root / 'out'), *options], text=True, capture_output=True, timeout=10)
                assert result.returncode == 0, result.stderr
                assert not any(secret in result.stdout for secret in ['private-body', 'private-cookie', 'private-guard', 'private-query'])
                metadata = json.loads(result.stdout)
                assert metadata['http_status'] == '200', metadata
                evidence = Path(metadata['evidence_directory'])
                assert not list(evidence.glob('request-*.private'))
                for file in evidence.iterdir():
                    assert stat.S_IMODE(file.stat().st_mode) == 0o600, file
                assert json.loads((evidence / 'response-body.private').read_text()) == {'ok': True}
                headers, payload = received.get(timeout=2)
                assert payload == body
                return {name.lower(): value for name, value in headers.items()}, metadata

            headers, metadata = run('--label', 'baseline')
            assert headers['cookie'] == 'session=private-cookie; guard=private-guard'
            assert headers['user-agent'] == 'CapturedBrowser/1'
            assert headers['accept-encoding'] == 'gzip' and metadata['compressed_flag']
            headers, metadata = run('--drop-header', 'User-Agent', '--drop-header', 'Accept', '--drop-header', 'Accept-Encoding', '--drop-header', 'Content-Type', '--omit-cookies')
            assert not any(name in headers for name in ['user-agent', 'accept', 'accept-encoding', 'content-type', 'cookie'])
            assert not metadata['compressed_flag'] and not metadata['cookie_names']
            headers, _ = run('--keep-cookie', 'session')
            assert headers['cookie'] == 'session=private-cookie'
            assert received.empty()
        print('PASS: exact native-curl replay, header absence, cookie filtering, private evidence and secret-free output.')
    finally:
        server.shutdown()
        server.server_close()
        worker.join(timeout=2)


if __name__ == '__main__':
    main()
