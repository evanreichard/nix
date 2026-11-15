#!/usr/bin/env python3
"""Inspect a HAR or replay one captured request with native curl; no third-party dependencies."""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import urllib.parse


def entries(path):
    with Path(path).open() as source:
        return json.load(source)['log']['entries']


def inspect(args):
    for index, entry in enumerate(entries(args.har)):
        request = entry['request']
        url = urllib.parse.urlsplit(request['url'])
        if args.host and url.hostname != args.host:
            continue
        segments = url.path.split('/')
        safe_path = '/'.join(
            '<id>' if len(segment) > 48 or (any(c.isdigit() for c in segment) and not re.fullmatch(r'v\d+', segment)) else segment
            for segment in segments
        )
        content = entry['response'].get('content', {})
        print(json.dumps({
            'index': index, 'method': request['method'], 'host': url.hostname,
            'path_hint': safe_path, 'query_names': list(urllib.parse.parse_qs(url.query)),
            'status': entry['response']['status'], 'mime': content.get('mimeType'),
            'size': content.get('size'), 'protocol': request.get('httpVersion'),
            'header_names': [header['name'] for header in request['headers']],
        }))


def private_file(path, data):
    with path.open('xb') as output:
        os.chmod(path, 0o600)
        output.write(data)


def replay(args):
    request = entries(args.har)[args.index]['request']
    url = request['url']
    if urllib.parse.urlsplit(url).scheme not in {'http', 'https'} or any(c in url for c in '\r\n'):
        raise ValueError('Replay requires an absolute HTTP(S) URL without line breaks')
    headers = []
    dropped = {name.lower() for name in args.drop_header}
    kept = {name.lower() for name in args.keep_header} if args.keep_header else None
    for header in request['headers']:
        name, value = header['name'], header['value']
        if name.startswith(':'):
            continue  # Protocol Fields - Curl derives HTTP/2 pseudoheaders from method and URL.
        if any(c in name + value for c in '\r\n'):
            raise ValueError('A captured header contains a line break; inspect it privately')
        if name.lower() in dropped or (kept is not None and name.lower() not in kept):
            continue
        if name.lower() == 'cookie':
            if args.omit_cookies:
                continue
            if args.keep_cookie is not None:
                parts = [part.strip() for part in value.split(';') if part.strip().split('=', 1)[0] in args.keep_cookie]
                if not parts:
                    continue
                value = '; '.join(parts)
        headers.append((name, value))
    post = request.get('postData')
    body = None
    if post is not None:
        if not isinstance(post.get('text'), str):
            raise ValueError('HAR omits raw postData.text; obtain a complete capture instead of inventing a body')
        body = base64.b64decode(post['text'], validate=True) if post.get('encoding') == 'base64' else post['text'].encode('utf-8')
    protocol = args.protocol
    if protocol == 'captured':
        version = request.get('httpVersion', '').upper()
        protocol = {'HTTP/1.0': 'http1.0', 'HTTP/1.1': 'http1.1', 'HTTP/2': 'http2', 'HTTP/2.0': 'http2', 'H2': 'http2', 'HTTP/3': 'http3', 'HTTP/3.0': 'http3', 'H3': 'http3'}.get(version)
    if not shutil.which('curl'):
        raise RuntimeError('Native curl is required')
    root = Path(args.out)
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(root, 0o700)
    label = re.sub(r'[^a-zA-Z0-9_-]', '-', args.label)
    run = Path(tempfile.mkdtemp(prefix=f'{label}-{args.index}-', dir=root))
    header_file = run / 'request-headers.private'
    body_file = run / 'request-body.private'
    response_file = run / 'response-body.private'
    response_headers = run / 'response-headers.private'
    private_file(header_file, ''.join(f'{name}: {value}\n' for name, value in headers).encode())
    private_file(response_file, b'')
    private_file(response_headers, b'')
    if body is not None:
        private_file(body_file, body)
    command = [
        'curl', '--disable', '--silent', '--show-error', '--max-time', str(args.timeout),
        '--request', request['method'],
        '--header', 'User-Agent:', '--header', 'Accept:', '--header', 'Content-Type:', '--header', 'Expect:',
        '--header', '@' + str(header_file),
        '--output', str(response_file), '--dump-header', str(response_headers),
        '--write-out', '%{http_code} %{http_version} %{content_type}', '--config', '-',
    ]
    if protocol:
        command.append('--' + protocol)
    compressed = any(name.lower() == 'accept-encoding' for name, _ in headers)
    if compressed:
        command.append('--compressed')
    if body is not None:
        command += ['--data-binary', '@' + str(body_file)]
    config = 'url = "' + url.replace('\\', '\\\\').replace('"', '\\"') + '"\n'
    try:
        result = subprocess.run(command, input=config, text=True, capture_output=True, timeout=args.timeout + 5)
    finally:
        header_file.unlink(missing_ok=True)
        body_file.unlink(missing_ok=True)
    stdout_file = run / 'curl-output.private'
    private_file(stdout_file, (result.stdout + '\n' + result.stderr).encode())
    version = subprocess.check_output(['curl', '--disable', '--version'], text=True)
    private_file(run / 'curl-version.txt', version.encode())
    status = result.stdout.split(' ', 2)
    cookie_names = [part.strip().split('=', 1)[0] for name, value in headers if name.lower() == 'cookie' for part in value.split(';') if part.strip()]
    metadata = {
        'entry': args.index, 'label': args.label, 'curl_exit': result.returncode,
        'http_status': status[0] if status else None,
        'http_version': status[1] if len(status) > 1 else None,
        'captured_protocol': request.get('httpVersion'), 'curl_version': version.splitlines()[0],
        'host': urllib.parse.urlsplit(url).hostname,
        'method': request['method'], 'supplied_header_names': [name for name, _ in headers],
        'cookie_names': cookie_names, 'request_body_bytes': len(body) if body is not None else 0,
        'request_body_sha256': hashlib.sha256(body).hexdigest() if body is not None else None,
        'compressed_flag': compressed, 'response_bytes': response_file.stat().st_size,
        'evidence_directory': str(run),
        'proxy_env_names': [name for name in ('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy') if os.environ.get(name)],
    }
    private_file(run / 'metadata.json', (json.dumps(metadata, indent=2) + '\n').encode())
    print(json.dumps(metadata, indent=2))
    return result.returncode


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    listing = commands.add_parser('inspect', help='List request metadata without header/query values')
    listing.add_argument('har')
    listing.add_argument('--host')
    listing.set_defaults(action=inspect)
    run = commands.add_parser('replay', help='Replay one request without redirects, retries or implicit cookies')
    run.add_argument('har')
    run.add_argument('index', type=int)
    run.add_argument('--out', required=True)
    run.add_argument('--label', default='replay')
    run.add_argument('--drop-header', action='append', default=[])
    run.add_argument('--keep-header', action='append', default=[])
    cookies = run.add_mutually_exclusive_group()
    cookies.add_argument('--omit-cookies', action='store_true')
    cookies.add_argument('--keep-cookie', action='append')
    run.add_argument('--protocol', choices=['captured', 'http1.0', 'http1.1', 'http2', 'http3'], default='captured')
    run.add_argument('--timeout', type=int, default=30)
    run.set_defaults(action=replay)
    args = parser.parse_args()
    if args.command == 'replay' and (args.index < 0 or args.timeout <= 0):
        parser.error('index must be nonnegative and timeout positive')
    return args.action(args) or 0


if __name__ == '__main__':
    raise SystemExit(main())
