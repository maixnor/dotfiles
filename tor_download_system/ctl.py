#!/usr/bin/env python3
import os
import sys
import json
import ssl
import urllib.request
import urllib.parse

SERVER_URL = os.environ.get("SERVER_URL", "https://tor-downloader.maixnor.com")

def _make_request(url, data=None, headers=None):
    if headers is None:
        headers = {}
    parsed = urllib.parse.urlparse(url)
    target_url = url
    ctx = None

    # If domain doesn't resolve locally yet, fallback to direct IP with Host header
    if parsed.hostname == "tor-downloader.maixnor.com":
        headers['Host'] = "tor-downloader.maixnor.com"
        target_url = urllib.parse.urlunparse((
            parsed.scheme, "37.205.9.77", parsed.path, parsed.params, parsed.query, parsed.fragment
        ))
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

    req_data = json.dumps(data).encode('utf-8') if data is not None else None
    if data is not None:
        headers['Content-Type'] = 'application/json'

    req = urllib.request.Request(target_url, data=req_data, headers=headers)
    with urllib.request.urlopen(req, context=ctx) as resp:
        return json.loads(resp.read().decode('utf-8'))

if len(sys.argv) < 2:
    print("Usage: ctl.py <status|seed <url>|tasks>")
    sys.exit(1)

cmd = sys.argv[1]

if cmd == "status":
    print(json.dumps(_make_request(f"{SERVER_URL}/api/status"), indent=2))
elif cmd == "seed":
    if len(sys.argv) < 3:
        print("Usage: ctl.py seed <url>")
        sys.exit(1)
    url = sys.argv[2]
    res = _make_request(f"{SERVER_URL}/api/queue", {"urls": [url]})
    print(json.dumps(res, indent=2))
elif cmd == "tasks":
    print(json.dumps(_make_request(f"{SERVER_URL}/api/tasks"), indent=2))
else:
    print(f"Unknown command: {cmd}")
