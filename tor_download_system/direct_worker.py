#!/usr/bin/env python3
"""
High-Concurrency Distributed Async Downloader Agent
Manages up to 1,000+ simultaneous download streams with efficient connection pooling
and async disk streaming.
"""

import os
import sys
import time
import json
import ssl
import asyncio
import aiohttp
import aiofiles
import argparse
import hashlib
import urllib.parse
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

def url_to_relative_path(url):
    parsed = urllib.parse.urlparse(url)
    path = urllib.parse.unquote(parsed.path.lstrip('/'))
    if path.startswith('data/'):
        path = path[5:]
    return path

async def compute_sha256_async(filepath):
    h = hashlib.sha256()
    async with aiofiles.open(filepath, 'rb') as f:
        while True:
            chunk = await f.read(65536)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

class DirectAsyncWorker:
    def __init__(self, worker_id, server_url, output_dir, concurrency=1000,
                 chunk_size=65536, direct_completion=False, api_key=""):
        self.worker_id = worker_id
        self.server_url = server_url.rstrip('/')
        self.output_dir = output_dir
        self.concurrency = concurrency
        self.chunk_size = chunk_size
        self.direct_completion = direct_completion
        self.api_key = api_key
        self.semaphore = asyncio.Semaphore(concurrency)
        self.active_tasks = set()
        self.session = None
        self.stats = {"completed": 0, "failed": 0, "bytes": 0}
        os.makedirs(self.output_dir, exist_ok=True)

    async def _post_json(self, endpoint, data):
        headers = {'Content-Type': 'application/json'}
        if self.api_key:
            headers['X-API-Key'] = self.api_key

        url = f"{self.server_url}{endpoint}"
        try:
            async with self.session.post(url, json=data, headers=headers, timeout=aiohttp.ClientTimeout(total=20)) as resp:
                if resp.status == 200:
                    return await resp.json()
                return None
        except Exception as e:
            return None

    async def download_file_stream(self, task):
        task_id = task["id"]
        url = task["url"]
        rel_path = url_to_relative_path(url)
        dest_path = os.path.join(self.output_dir, rel_path)
        os.makedirs(os.path.dirname(dest_path), exist_ok=True)

        part_path = f"{dest_path}.part"

        async with self.semaphore:
            try:
                # Check resume offset if partial file exists
                resume_pos = 0
                headers = {}
                if os.path.exists(part_path):
                    resume_pos = os.path.getsize(part_path)
                    if resume_pos > 0:
                        headers['Range'] = f"bytes={resume_pos}-"

                client_timeout = aiohttp.ClientTimeout(total=1800, connect=30, sock_read=120)
                async with self.session.get(url, headers=headers, timeout=client_timeout) as resp:
                    if resp.status not in (200, 206):
                        raise Exception(f"HTTP {resp.status} {resp.reason}")

                    mode = 'ab' if (resp.status == 206 and resume_pos > 0) else 'wb'
                    bytes_downloaded = resume_pos if mode == 'ab' else 0

                    async with aiofiles.open(part_path, mode) as f:
                        async for chunk in resp.content.iter_chunked(self.chunk_size):
                            if chunk:
                                await f.write(chunk)
                                bytes_downloaded += len(chunk)
                                self.stats["bytes"] += len(chunk)

                # Atomic rename after download completes
                if os.path.exists(dest_path):
                    os.remove(dest_path)
                os.rename(part_path, dest_path)

                file_size = os.path.getsize(dest_path)
                file_hash = await compute_sha256_async(dest_path)

                if self.direct_completion:
                    await self._post_json("/api/report_completed", {
                        "task_id": task_id,
                        "local_rel_path": rel_path,
                        "file_size": file_size,
                        "file_hash": file_hash
                    })
                else:
                    await self._post_json("/api/report_staging", {
                        "task_id": task_id,
                        "url": url,
                        "worker_id": self.worker_id,
                        "staging_path": dest_path,
                        "file_size": file_size,
                        "file_hash": file_hash,
                        "discovered_urls": []
                    })

                self.stats["completed"] += 1

            except Exception as e:
                self.stats["failed"] += 1
                await self._post_json("/api/report_failed", {
                    "task_id": task_id,
                    "error": str(e)
                })

    async def crawl_directory(self, task):
        task_id = task["id"]
        url = task["url"]

        async with self.semaphore:
            try:
                client_timeout = aiohttp.ClientTimeout(total=60, connect=20)
                async with self.session.get(url, timeout=client_timeout) as resp:
                    if resp.status != 200:
                        raise Exception(f"HTTP {resp.status} fetching directory listing")
                    html_content = await resp.text()

                parser = DirectoryLinkParser(url)
                parser.feed(html_content)
                discovered = list(set(parser.links))

                await self._post_json("/api/report_staging", {
                    "task_id": task_id,
                    "url": url,
                    "worker_id": self.worker_id,
                    "staging_path": "",
                    "file_size": 0,
                    "file_hash": "",
                    "discovered_urls": discovered
                })
                self.stats["completed"] += 1

            except Exception as e:
                self.stats["failed"] += 1
                await self._post_json("/api/report_failed", {
                    "task_id": task_id,
                    "error": str(e)
                })

    async def handle_task(self, task):
        try:
            url = task.get("url", "")
            is_dir = task.get("is_dir", 0) or url.endswith('/')
            if is_dir:
                await self.crawl_directory(task)
            else:
                await self.download_file_stream(task)
        finally:
            self.active_tasks.discard(task["id"])

    async def claim_tasks_batch(self, count):
        claim_data = {
            "worker_id": self.worker_id,
            "batch_size": count
        }
        res = await self._post_json("/api/claim", claim_data)
        if not res:
            return []
        if "tasks" in res:
            return res["tasks"]
        if "task" in res and res["task"]:
            return [res["task"]]
        return []

    async def run(self):
        # Configure High-Concurrency TCP Connector
        connector = aiohttp.TCPConnector(
            limit=self.concurrency * 2,
            limit_per_host=self.concurrency,
            ttl_dns_cache=300,
            enable_cleanup_closed=True,
            ssl=False
        )

        async with aiohttp.ClientSession(connector=connector) as session:
            self.session = session
            print(f"[{self.worker_id}] Async Direct Downloader started.")
            print(f"[{self.worker_id}] Target Coordinator: {self.server_url}")
            print(f"[{self.worker_id}] Stream Concurrency: {self.concurrency} concurrent streams")
            print(f"[{self.worker_id}] Output Directory: {self.output_dir}")

            last_log = time.time()

            while True:
                needed = self.concurrency - len(self.active_tasks)
                if needed > 0:
                    batch_size = min(needed, 100)
                    new_tasks = await self.claim_tasks_batch(batch_size)
                    if new_tasks:
                        for t in new_tasks:
                            self.active_tasks.add(t["id"])
                            asyncio.create_task(self.handle_task(t))
                    else:
                        await asyncio.sleep(1)
                else:
                    await asyncio.sleep(0.1)

                now = time.time()
                if now - last_log >= 10:
                    mb_downloaded = self.stats["bytes"] / (1024 * 1024)
                    print(f"[{self.worker_id}] Active Streams: {len(self.active_tasks)}/{self.concurrency} | Completed: {self.stats['completed']} | Failed: {self.stats['failed']} | Total: {mb_downloaded:.1f} MB")
                    last_log = now

def main():
    parser = argparse.ArgumentParser(description="High-Concurrency Async Downloader Agent")
    parser.add_argument('--worker-id', default='direct-agent-1')
    parser.add_argument('--server-url', default='https://tor-downloader.maixnor.com')
    parser.add_argument('--output-dir', default='/data/download')
    parser.add_argument('--concurrency', type=int, default=1000)
    parser.add_argument('--chunk-size', type=int, default=65536)
    parser.add_argument('--direct-completion', action='store_true', help='Mark completed directly in database without rsync sink')
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

    worker = DirectAsyncWorker(
        worker_id=args.worker_id,
        server_url=args.server_url,
        output_dir=args.output_dir,
        concurrency=args.concurrency,
        chunk_size=args.chunk_size,
        direct_completion=args.direct_completion,
        api_key=api_key
    )

    try:
        asyncio.run(worker.run())
    except KeyboardInterrupt:
        print("\nShutdown requested. Exiting cleanly.")

if __name__ == '__main__':
    main()
