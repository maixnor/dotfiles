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

DATA_SINK_DIR = os.environ.get("DATA_SINK_DIR", "/data/download")
SERVER_URL = os.environ.get("SERVER_URL", "https://tor-downloader.maixnor.com")
SOURCE_HOST = os.environ.get("SOURCE_HOST", "maixnor.com")
SSH_USER = os.environ.get("SSH_USER", "maixnor")
SSH_IDENTITY_FILE = os.environ.get("SSH_IDENTITY_FILE", "/home/maixnor/.ssh/id_ed25519")
API_KEY_FILE = os.environ.get("API_KEY_FILE", "/run/secrets/tor-downloader-api-key")

def url_to_relative_path(url):
    parsed = urllib.parse.urlparse(url)
    path = urllib.parse.unquote(parsed.path.lstrip('/'))
    if path.startswith('data/'):
        path = path[5:]
    return path

def compute_sha256(filepath):
    h = hashlib.sha256()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(65536), b''):
            h.update(chunk)
    return h.hexdigest()

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

class SinkCollector:
    def __init__(self, server_url, source_host, dest_dir, ssh_user="maixnor", ssh_key="/home/maixnor/.ssh/id_ed25519", api_key=""):
        self.server_url = server_url.rstrip('/')
        self.source_host = source_host
        self.dest_dir = dest_dir
        self.ssh_user = ssh_user
        self.ssh_key = ssh_key
        self.api_key = api_key
        os.makedirs(self.dest_dir, exist_ok=True)

    def _request(self, endpoint, method="GET", data=None):
        headers = {}
        if self.api_key:
            headers['X-API-Key'] = self.api_key
        if data is not None:
            headers['Content-Type'] = 'application/json'

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

        req_data = json.dumps(data).encode('utf-8') if data is not None else None
        req = urllib.request.Request(target_url, data=req_data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=20, context=ctx) as resp:
                return json.loads(resp.read().decode('utf-8'))
        except Exception as e:
            print(f"[Sink] Error {method} {endpoint}: {e}")
            return None

    def process_task(self, task):
        task_id = task['id']
        url = task['url']
        staging_path = task['staging_path']
        is_dir = task['is_dir']

        if is_dir or not staging_path:
            rel_path = url_to_relative_path(url)
            self._request("/api/report_completed", "POST", {
                "task_id": task_id,
                "local_rel_path": rel_path,
                "file_size": 0,
                "file_hash": ""
            })
            print(f"[Sink] Directory task {task_id} marked completed: {rel_path}")
            return

        rel_path = url_to_relative_path(url)
        dest_file = os.path.join(self.dest_dir, rel_path)
        ensure_parent_dirs(dest_file)

        if os.path.isdir(dest_file):
            self._request("/api/report_completed", "POST", {
                "task_id": task_id,
                "local_rel_path": rel_path,
                "file_size": 0,
                "file_hash": ""
            })
            return

        # Local Staging Fast-Path (for local worker agents on Bierbasis)
        if os.path.exists(staging_path) and os.path.isfile(staging_path):
            import shutil
            try:
                shutil.move(staging_path, dest_file)
            except Exception:
                # If cross-device move
                shutil.copy2(staging_path, dest_file)
                try:
                    os.remove(staging_path)
                except Exception:
                    pass

            file_size = os.path.getsize(dest_file) if os.path.exists(dest_file) else 0
            file_hash = compute_sha256(dest_file) if os.path.exists(dest_file) else ""

            self._request("/api/report_completed", "POST", {
                "task_id": task_id,
                "local_rel_path": rel_path,
                "file_size": file_size,
                "file_hash": file_hash
            })
            print(f"[Sink] Local fast-path completed task {task_id}: {rel_path} ({file_size} bytes)")
            return

        print(f"[Sink] Pulling task {task_id} from {self.ssh_user}@{self.source_host}:{staging_path} -> {dest_file}")

        ssh_opts = f"ssh -i {self.ssh_key} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

        rsync_cmd = [
            "rsync", "-avz", "-e", ssh_opts,
            f"{self.ssh_user}@{self.source_host}:{staging_path}", dest_file
        ]
        res = subprocess.run(rsync_cmd, capture_output=True, text=True)
        if res.returncode == 0 and os.path.exists(dest_file):
            file_size = os.path.getsize(dest_file)
            file_hash = compute_sha256(dest_file)

            self._request("/api/report_completed", "POST", {
                "task_id": task_id,
                "local_rel_path": rel_path,
                "file_size": file_size,
                "file_hash": file_hash
            })

            cleanup_cmd = [
                "ssh", "-i", self.ssh_key, "-o", "IdentitiesOnly=yes", "-o", "StrictHostKeyChecking=accept-new",
                f"{self.ssh_user}@{self.source_host}", f"sudo rm -f {subprocess.list2cmdline([staging_path])}"
            ]
            subprocess.run(cleanup_cmd, capture_output=True)
            print(f"[Sink] Completed task {task_id}: {rel_path} ({file_size} bytes). Remote staging cleaned up.")
        else:
            print(f"[Sink] ERROR: rsync failed for task {task_id}: {res.stderr}")
            self._request("/api/report_failed", "POST", {"task_id": task_id, "error": f"rsync failed: {res.stderr}"})

    def run_loop(self):
        import concurrent.futures
        print(f"[Sink] Sink Collector starting. Server: {self.server_url}, Source: {self.ssh_user}@{self.source_host}, Dest: {self.dest_dir}")
        while True:
            try:
                resp = self._request("/api/staging_tasks", "GET")
                if resp and resp.get("tasks"):
                    tasks = resp["tasks"]
                    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
                        futures = [executor.submit(self.process_task, t) for t in tasks]
                        for f in concurrent.futures.as_completed(futures):
                            try:
                                f.result()
                            except Exception as e:
                                print(f"[Sink] Task processing error: {e}")
            except Exception as e:
                print(f"[Sink] Loop error: {e}")
            time.sleep(3)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--server-url', default=SERVER_URL)
    parser.add_argument('--source-host', default=SOURCE_HOST)
    parser.add_argument('--ssh-user', default=SSH_USER)
    parser.add_argument('--ssh-key', default=SSH_IDENTITY_FILE)
    parser.add_argument('--destination-dir', default=DATA_SINK_DIR)
    parser.add_argument('--api-key-file', default=API_KEY_FILE)
    parser.add_argument('--api-key', default='')
    args = parser.parse_args()

    api_key = args.api_key
    if not api_key and os.path.exists(args.api_key_file):
        try:
            with open(args.api_key_file, 'r') as f:
                api_key = f.read().strip()
        except Exception:
            pass

    sink = SinkCollector(
        server_url=args.server_url,
        source_host=args.source_host,
        dest_dir=args.destination_dir,
        ssh_user=args.ssh_user,
        ssh_key=args.ssh_key,
        api_key=api_key
    )
    sink.run_loop()
