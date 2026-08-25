#!/usr/bin/env python3
import os
import sys
import time
import json
import ssl
import argparse
import subprocess
import hashlib
import urllib.parse
import urllib.request
from html.parser import HTMLParser

class DirectoryLinkParser(HTMLParser):
    def __init__(self, base_url):
        super().__init__()
        self.base_url = base_url
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag == 'a':
            for attr, val in attrs:
                if attr == 'href' and val:
                    val = val.strip()
                    if val.startswith(('?', '#', '../', '/..')) or val in ('./', '../'):
                        continue
                    full_url = urllib.parse.urljoin(self.base_url, val)
                    base_netloc = urllib.parse.urlparse(self.base_url).netloc
                    link_netloc = urllib.parse.urlparse(full_url).netloc
                    if base_netloc == link_netloc and full_url != self.base_url:
                        self.links.append(full_url)

def compute_sha256(filepath):
    h = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(65536), b''):
            h.update(chunk)
    return h.hexdigest()

def url_to_relative_path(url):
    parsed = urllib.parse.urlparse(url)
    path = urllib.parse.unquote(parsed.path.lstrip('/'))
    if path.startswith('data/'):
        path = path[5:]
    return path

def ensure_parent_dirs(path):
    parent = os.path.dirname(path)
    if not parent:
        return
    parts = parent.strip('/').split('/')
    curr = "/" if parent.startswith('/') else ""
    for p in parts:
        curr = os.path.join(curr, p)
        if os.path.isfile(curr):
            try:
                os.remove(curr)
            except Exception:
                pass
        os.makedirs(curr, exist_ok=True)

class TorWorker:
    def __init__(self, worker_id, server_url, socks_proxy, staging_dir, api_key="", dest_dir=""):
        self.worker_id = worker_id
        self.server_url = server_url.rstrip('/')
        self.socks_proxy = socks_proxy
        self.staging_dir = staging_dir
        self.dest_dir = dest_dir
        self.api_key = api_key
        os.makedirs(self.staging_dir, exist_ok=True)
        if self.dest_dir and os.path.exists(os.path.dirname(self.dest_dir)):
            try:
                os.makedirs(self.dest_dir, exist_ok=True)
            except Exception:
                pass

    def _post(self, endpoint, data):
        headers = {'Content-Type': 'application/json'}
        if self.api_key:
            headers['X-API-Key'] = self.api_key

        url = f"{self.server_url}{endpoint}"
        parsed = urllib.parse.urlparse(url)
        target_url = url
        ctx = None

        if parsed.scheme == 'https':
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE

        if parsed.hostname == "tor-downloader.maixnor.com":
            headers['Host'] = "tor-downloader.maixnor.com"
            try:
                import socket
                socket.gethostbyname("tor-downloader.maixnor.com")
            except Exception:
                target_url = urllib.parse.urlunparse((
                    parsed.scheme, "37.205.9.77", parsed.path, parsed.params, parsed.query, parsed.fragment
                ))

        req = urllib.request.Request(
            target_url,
            data=json.dumps(data).encode('utf-8'),
            headers=headers
        )
        for attempt in range(3):
            try:
                with urllib.request.urlopen(req, timeout=15, context=ctx) as resp:
                    return json.loads(resp.read().decode('utf-8'))
            except Exception as e:
                if attempt == 2:
                    print(f"[{self.worker_id}] Error posting to {endpoint}: {e}")
                    return None
                time.sleep(1)
        return None

    def fetch_url_content(self, url):
        last_err = ""
        for attempt in range(5):
            cmd = ["curl", "--socks5-hostname", self.socks_proxy, "-s", "-L", "--connect-timeout", "25", "--max-time", "60", url]
            res = subprocess.run(cmd, capture_output=True, text=True)
            if res.returncode == 0 and len(res.stdout.strip()) > 50:
                if "429 Too Many Requests" in res.stdout:
                    raise Exception("HTTP 429 Too Many Requests")
                return res.stdout
            if "429 Too Many Requests" in (res.stdout or ""):
                raise Exception("HTTP 429 Too Many Requests")
            last_err = res.stderr or f"empty response (code {res.returncode})"
            time.sleep(2)
        raise Exception(f"Failed to fetch directory HTML after 5 attempts: {last_err}")

    def download_file(self, url, dest_path):
        ensure_parent_dirs(dest_path)
        if os.path.isdir(dest_path):
            return
        
        last_error = ""
        for attempt in range(15):
            cmd = [
                "curl", "--socks5-hostname", self.socks_proxy,
                "-L", "-C", "-",
                "--tcp-nodelay",
                "--buffer-size", "65536",
                "--connect-timeout", "20",
                "--speed-time", "30", "--speed-limit", "1024",
                "-o", dest_path, url
            ]
            res = subprocess.run(cmd, capture_output=True, text=True)
            if res.returncode == 0:
                if os.path.exists(dest_path):
                    # Check if small payload is actually a 429 error response
                    if os.path.getsize(dest_path) < 2048:
                        try:
                            with open(dest_path, 'r', errors='ignore') as f:
                                txt = f.read()
                            if "429 Too Many Requests" in txt or ("429" in txt and "rate limit" in txt.lower()):
                                os.remove(dest_path)
                                raise Exception("HTTP 429 Too Many Requests")
                        except Exception as e:
                            if "429" in str(e):
                                raise
                    return
                break
            last_error = f"curl download failed (code {res.returncode}): {res.stderr}"
            if res.returncode in (18, 28, 52, 56):
                time.sleep(2)
                continue
            else:
                break

        if not os.path.exists(dest_path) or res.returncode != 0:
            raise Exception(last_error or f"curl download failed (code {res.returncode})")

    def run_step(self):
        resp = self._post("/api/claim", {"worker_id": self.worker_id})
        if not resp or not resp.get("task"):
            return False

        task = resp["task"]
        task_id = task["id"]
        url = task["url"]
        is_dir = task["is_dir"]

        print(f"[{self.worker_id}] Claimed task {task_id}: {url} (is_dir={is_dir})")

        try:
            if is_dir or url.endswith('/'):
                html = self.fetch_url_content(url)
                parser = DirectoryLinkParser(url)
                parser.feed(html)
                discovered = list(set(parser.links))
                print(f"[{self.worker_id}] Directory crawl discovered {len(discovered)} links.")
                
                self._post("/api/report_staging", {
                    "task_id": task_id,
                    "url": url,
                    "worker_id": self.worker_id,
                    "staging_path": "",
                    "file_size": 0,
                    "file_hash": "",
                    "discovered_urls": discovered
                })
            else:
                rel_path = url_to_relative_path(url)
                
                # Check if direct destination directory exists locally (e.g. /data/download)
                use_direct = bool(self.dest_dir and os.path.isdir(self.dest_dir))
                target_file = os.path.join(self.dest_dir, rel_path) if use_direct else os.path.join(self.staging_dir, rel_path)

                self.download_file(url, target_file)

                if os.path.isdir(target_file):
                    if use_direct:
                        self._post("/api/report_completed", {
                            "task_id": task_id,
                            "local_rel_path": rel_path,
                            "file_size": 0,
                            "file_hash": ""
                        })
                    else:
                        self._post("/api/report_staging", {
                            "task_id": task_id,
                            "url": url,
                            "worker_id": self.worker_id,
                            "staging_path": "",
                            "file_size": 0,
                            "file_hash": "",
                            "discovered_urls": []
                        })
                    return True

                file_size = os.path.getsize(target_file)

                # Check if downloaded file is actually an HTML directory index page
                if file_size < 1000000:
                    try:
                        with open(target_file, 'r', errors='ignore') as f:
                            head_content = f.read(4096)
                        if '<title>Index of' in head_content or '<h1>Index of' in head_content or '<pre><a href=' in head_content or '<title>Storage —' in head_content:
                            with open(target_file, 'r', errors='ignore') as f:
                                full_html = f.read()
                            os.remove(target_file)
                            parser = DirectoryLinkParser(url)
                            parser.feed(full_html)
                            discovered = list(set(parser.links))
                            print(f"[{self.worker_id}] Auto-detected HTML directory listing for {url}: {len(discovered)} links.")
                            self._post("/api/report_staging", {
                                "task_id": task_id,
                                "url": url,
                                "worker_id": self.worker_id,
                                "staging_path": "",
                                "file_size": 0,
                                "file_hash": "",
                                "discovered_urls": discovered
                            })
                            return True
                    except Exception:
                        pass

                file_hash = compute_sha256(target_file)

                if use_direct:
                    print(f"[{self.worker_id}] Downloaded directly to sink: {target_file} ({file_size} bytes)")
                    self._post("/api/report_completed", {
                        "task_id": task_id,
                        "local_rel_path": rel_path,
                        "file_size": file_size,
                        "file_hash": file_hash
                    })
                else:
                    print(f"[{self.worker_id}] Downloaded {url} to staging: {target_file} ({file_size} bytes)")
                    self._post("/api/report_staging", {
                        "task_id": task_id,
                        "url": url,
                        "worker_id": self.worker_id,
                        "staging_path": target_file,
                        "file_size": file_size,
                        "file_hash": file_hash,
                        "discovered_urls": []
                    })

        except Exception as e:
            if "429" in str(e) or "Too Many Requests" in str(e) or "rate limit" in str(e).lower():
                print(f"[{self.worker_id}] Rate limited (429) on task {task_id}: {e}. Requeuing without failure penalty.")
                self._post("/api/requeue", {"task_id": task_id})
                time.sleep(5)
            else:
                print(f"[{self.worker_id}] Task {task_id} failed: {e}")
                self._post("/api/report_failed", {"task_id": task_id, "error": str(e)})

        return True

    def loop(self):
        print(f"[{self.worker_id}] Starting worker loop. Server: {self.server_url}, Proxy: {self.socks_proxy}, Staging: {self.staging_dir}")
        while True:
            had_task = self.run_step()
            if not had_task:
                time.sleep(3)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--worker-id', required=True)
    parser.add_argument('--server-url', default='https://tor-downloader.maixnor.com')
    parser.add_argument('--socks-proxy', default='127.0.0.1:9050')
    parser.add_argument('--staging-dir', default='/var/lib/tor-downloader/staging')
    parser.add_argument('--destination-dir', default='/data/download')
    parser.add_argument('--api-key-file', default='/run/secrets/tor-downloader-api-key')
    parser.add_argument('--api-key', default='')
    args = parser.parse_args()

    api_key = args.api_key
    if not api_key and os.path.exists(args.api_key_file):
        try:
            with open(args.api_key_file, 'r') as f:
                api_key = f.read().strip()
        except Exception:
            pass

    worker = TorWorker(args.worker_id, args.server_url, args.socks_proxy, args.staging_dir, api_key, args.destination_dir)
    worker.loop()
