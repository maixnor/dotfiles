#!/usr/bin/env python3
import sqlite3
import json
import time
import os
import sys
import traceback
import urllib.parse
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

DB_PATH = os.environ.get("QUEUE_DB_PATH", "/var/lib/tor-downloader/queue.db")
API_KEY_FILE = os.environ.get("API_KEY_FILE", "/run/secrets/tor-downloader-api-key")
API_KEY_ENV = os.environ.get("TOR_DOWNLOADER_API_KEY", "")

PAUSED_STATE_FILE = os.path.join(os.path.dirname(DB_PATH), "paused.flag")

def is_paused():
    return os.path.exists(PAUSED_STATE_FILE)

def set_paused(paused=True):
    if paused:
        with open(PAUSED_STATE_FILE, 'w') as f:
            f.write("1")
    else:
        if os.path.exists(PAUSED_STATE_FILE):
            os.remove(PAUSED_STATE_FILE)

def load_api_key():
    if API_KEY_ENV:
        return API_KEY_ENV.strip()
    if os.path.exists(API_KEY_FILE):
        try:
            with open(API_KEY_FILE, 'r') as f:
                return f.read().strip()
        except Exception:
            pass
    return ""

SECRET_KEY = load_api_key()

def get_db():
    conn = sqlite3.connect(DB_PATH, timeout=60.0)
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = get_db()
    c = conn.cursor()
    c.execute('''
        CREATE TABLE IF NOT EXISTS tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            url TEXT UNIQUE NOT NULL,
            parent_url TEXT,
            is_dir INTEGER DEFAULT 0,
            status TEXT DEFAULT 'pending',
            worker_id TEXT,
            local_rel_path TEXT,
            staging_path TEXT,
            file_size INTEGER DEFAULT 0,
            file_hash TEXT,
            attempts INTEGER DEFAULT 0,
            error_message TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    c.execute('''
        CREATE TABLE IF NOT EXISTS workers (
            worker_id TEXT PRIMARY KEY,
            last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            tasks_completed INTEGER DEFAULT 0
        )
    ''')
    c.execute('CREATE INDEX IF NOT EXISTS idx_status ON tasks(status)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_url ON tasks(url)')
    conn.commit()
    conn.close()

def update_worker_heartbeat(conn, worker_id, increment_task=False):
    c = conn.cursor()
    if increment_task:
        c.execute('''
            INSERT INTO workers (worker_id, last_seen, tasks_completed)
            VALUES (?, CURRENT_TIMESTAMP, 1)
            ON CONFLICT(worker_id) DO UPDATE SET
                last_seen = CURRENT_TIMESTAMP,
                tasks_completed = tasks_completed + 1
        ''', (worker_id,))
    else:
        c.execute('''
            INSERT INTO workers (worker_id, last_seen, tasks_completed)
            VALUES (?, CURRENT_TIMESTAMP, 0)
            ON CONFLICT(worker_id) DO UPDATE SET
                last_seen = CURRENT_TIMESTAMP
        ''', (worker_id,))

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tor Download Manager — Wieselburg</title>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap">
    <style>
        :root {
            --bg-color: #0b0f19;
            --card-bg: #151c2c;
            --border-color: #232d42;
            --primary: #3b82f6;
            --primary-hover: #2563eb;
            --text-main: #f3f4f6;
            --text-muted: #9ca3af;
            --success: #10b981;
            --warning: #f59e0b;
            --danger: #ef4444;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Inter', sans-serif;
            background-color: var(--bg-color);
            color: var(--text-main);
            padding: 24px;
            line-height: 1.5;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 28px;
            padding-bottom: 16px;
            border-bottom: 1px solid var(--border-color);
        }
        h1 { font-size: 24px; font-weight: 700; color: #fff; }
        .subtitle { color: var(--text-muted); font-size: 14px; }
        .actions { display: flex; gap: 10px; align-items: center; }
        .btn {
            background: var(--card-bg);
            border: 1px solid var(--border-color);
            color: var(--text-main);
            padding: 8px 16px;
            border-radius: 6px;
            cursor: pointer;
            font-weight: 500;
            font-size: 14px;
            text-decoration: none;
            display: inline-block;
        }
        .btn:hover { background: var(--border-color); }
        .btn-pause { background: rgba(245, 158, 11, 0.2); color: var(--warning); border-color: var(--warning); }
        .btn-pause:hover { background: rgba(245, 158, 11, 0.3); }
        .btn-resume { background: rgba(16, 185, 129, 0.2); color: var(--success); border-color: var(--success); }
        .btn-resume:hover { background: rgba(16, 185, 129, 0.3); }
        .btn-danger { background: rgba(239, 68, 68, 0.2); color: var(--danger); border-color: var(--danger); }
        .btn-danger:hover { background: rgba(239, 68, 68, 0.3); }

        .grid-stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
            margin-bottom: 28px;
        }
        .stat-card {
            background: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 20px;
        }
        .stat-label { font-size: 13px; color: var(--text-muted); margin-bottom: 4px; font-weight: 500; }
        .stat-value { font-size: 26px; font-weight: 700; color: #fff; }
        .stat-sub { font-size: 12px; color: var(--text-muted); margin-top: 4px; }
        
        .section-title { font-size: 18px; font-weight: 600; margin-bottom: 14px; color: #fff; }
        .card {
            background: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 28px;
        }
        form.seed-form { display: flex; gap: 12px; }
        input[type="text"] {
            flex: 1;
            background: var(--bg-color);
            border: 1px solid var(--border-color);
            border-radius: 6px;
            padding: 10px 14px;
            color: #fff;
            font-size: 14px;
        }
        input[type="text"]:focus { outline: none; border-color: var(--primary); }
        button.btn-submit {
            background: var(--primary);
            color: #fff;
            border: none;
            padding: 10px 20px;
            border-radius: 6px;
            font-weight: 600;
            font-size: 14px;
            cursor: pointer;
        }
        button.btn-submit:hover { background: var(--primary-hover); }

        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { padding: 12px 16px; text-align: left; border-bottom: 1px solid var(--border-color); font-size: 13px; }
        th { background: rgba(0,0,0,0.2); color: var(--text-muted); font-weight: 600; text-transform: uppercase; font-size: 11px; letter-spacing: 0.05em; }
        tr:hover { background: rgba(255,255,255,0.02); }
        .badge {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
        }
        .badge-pending { background: rgba(245, 158, 11, 0.15); color: var(--warning); }
        .badge-assigned { background: rgba(59, 130, 246, 0.15); color: var(--primary); }
        .badge-staging { background: rgba(16, 185, 129, 0.15); color: #34d399; }
        .badge-completed { background: rgba(16, 185, 129, 0.25); color: var(--success); }
        .badge-failed { background: rgba(239, 68, 68, 0.2); color: var(--danger); }
        
        .url-cell { font-family: monospace; max-width: 450px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div>
                <h1>Tor Download Manager STATUS_BADGE</h1>
                <div class="subtitle">Wieselburg Coordinator & Distribution Hub</div>
            </div>
            <div class="actions">
                PAUSE_RESUME_BTN
                <button class="btn btn-danger" onclick="if(confirm('Stop & clear all pending queued downloads?')) location.href='/ui/clear_pending'">Stop & Clear Queue</button>
                <button class="btn" onclick="location.reload()">Refresh (F5)</button>
            </div>
        </header>

        <div class="grid-stats">
            <div class="stat-card">
                <div class="stat-label">Total Catalog Items</div>
                <div class="stat-value">TOTAL_TASKS</div>
                <div class="stat-sub">Discovered URLs</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Pending Downloads</div>
                <div class="stat-value" style="color: var(--warning)">PENDING_TASKS</div>
                <div class="stat-sub">In queue</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Completed Payload</div>
                <div class="stat-value" style="color: var(--success)">COMPLETED_SIZE</div>
                <div class="stat-sub">COMPLETED_COUNT files ingested</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Active Worker Agents</div>
                <div class="stat-value" style="color: var(--primary)">ACTIVE_WORKERS</div>
                <div class="stat-sub">WORKER_NAMES</div>
            </div>
        </div>

        <div class="card">
            <div class="section-title">Seed New Onion Target</div>
            <form class="seed-form" method="POST" action="/ui/add_url">
                <input type="text" name="url" placeholder="http://xxxxxxxx.onion/data/target/" required />
                <button type="submit" class="btn-submit">Add Target URL</button>
            </form>
        </div>

        <div class="card">
            <div class="section-title">Recent Tasks & Discovered Items</div>
            <table>
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Target URL</th>
                        <th>Status</th>
                        <th>Worker</th>
                        <th>Size</th>
                        <th>Updated At</th>
                    </tr>
                </thead>
                <tbody>
                    TASKS_ROWS
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
"""

class QueueHandler(BaseHTTPRequestHandler):
    def _send_json(self, data, code=200):
        body = json.dumps(data).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_html(self, html_content, code=200):
        body = html_content.encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _check_auth(self):
        if not SECRET_KEY:
            return True
        key = self.headers.get("X-API-Key", "")
        if not key:
            parsed = urllib.parse.urlparse(self.path)
            params = urllib.parse.parse_qs(parsed.query)
            key = params.get("api_key", [""])[0]
        return key == SECRET_KEY

    def _get_body(self):
        content_len = int(self.headers.get('Content-Length', 0))
        if content_len == 0:
            return {}
        post_body = self.rfile.read(content_len)
        content_type = self.headers.get('Content-Type', '')
        if 'application/x-www-form-urlencoded' in content_type:
            parsed = urllib.parse.parse_qs(post_body.decode('utf-8'))
            return {k: v[0] for k, v in parsed.items()}
        return json.loads(post_body.decode('utf-8'))

    def log_message(self, format, *args):
        pass

    def do_GET(self):
        try:
            parsed = urllib.parse.urlparse(self.path)

            if parsed.path in ('/ui/toggle_pause', '/ui/clear_pending'):
                if parsed.path == '/ui/toggle_pause':
                    set_paused(not is_paused())
                elif parsed.path == '/ui/clear_pending':
                    conn = get_db()
                    c = conn.cursor()
                    c.execute("UPDATE tasks SET status='cancelled' WHERE status='pending'")
                    conn.commit()
                    conn.close()
                self.send_response(303)
                self.send_header('Location', '/ui')
                self.end_headers()
                return

            if parsed.path in ('/', '/ui'):
                conn = get_db()
                c = conn.cursor()
                c.execute('SELECT status, count(*) as count FROM tasks GROUP BY status')
                stats = {row['status']: row['count'] for row in c.fetchall()}
                
                c.execute('SELECT count(*) as total, sum(file_size) as total_bytes FROM tasks WHERE status="completed"')
                completed_info = c.fetchone()
                
                # Active workers within last 5 minutes
                c.execute("SELECT worker_id, datetime(last_seen, 'localtime') as ls FROM workers WHERE datetime(last_seen) >= datetime('now', '-5 minutes')")
                active_worker_rows = c.fetchall()
                workers = [r['worker_id'] for r in active_worker_rows]

                c.execute('SELECT count(*) as count FROM tasks')
                total_tasks = c.fetchone()['count']

                c.execute('SELECT * FROM tasks ORDER BY id DESC LIMIT 50')
                recent_tasks = [dict(r) for r in c.fetchall()]
                conn.close()

                comp_bytes = completed_info['total_bytes'] or 0
                if comp_bytes > 1073741824:
                    comp_size_str = f"{comp_bytes / 1073741824:.2f} GB"
                else:
                    comp_size_str = f"{comp_bytes / 1048576:.1f} MB"

                rows_html = ""
                for t in recent_tasks:
                    badge_cls = f"badge-{t['status']}"
                    size_str = f"{t['file_size']} B" if t['file_size'] else "-"
                    worker_str = t['worker_id'] or "-"
                    rows_html += f"""<tr>
                        <td>{t['id']}</td>
                        <td class="url-cell" title="{t['url']}">{t['url']}</td>
                        <td><span class="badge {badge_cls}">{t['status']}</span></td>
                        <td>{worker_str}</td>
                        <td>{size_str}</td>
                        <td>{t['updated_at']}</td>
                    </tr>"""

                paused = is_paused()
                status_badge = '<span class="badge badge-failed" style="margin-left: 8px;">PAUSED</span>' if paused else '<span class="badge badge-completed" style="margin-left: 8px;">ACTIVE</span>'
                pause_btn = '<a href="/ui/toggle_pause" class="btn btn-resume">Resume Queue</a>' if paused else '<a href="/ui/toggle_pause" class="btn btn-pause">Pause Queue</a>'

                html = HTML_TEMPLATE
                html = html.replace("STATUS_BADGE", status_badge)
                html = html.replace("PAUSE_RESUME_BTN", pause_btn)
                html = html.replace("TOTAL_TASKS", f"{total_tasks:,}")
                html = html.replace("PENDING_TASKS", f"{stats.get('pending', 0):,}")
                html = html.replace("COMPLETED_SIZE", comp_size_str)
                html = html.replace("COMPLETED_COUNT", f"{completed_info['total'] or 0:,}")
                html = html.replace("ACTIVE_WORKERS", str(len(workers)))
                html = html.replace("WORKER_NAMES", ", ".join(workers) if workers else "None active in last 5m")
                html = html.replace("TASKS_ROWS", rows_html)

                self._send_html(html)

            elif parsed.path == '/api/status':
                conn = get_db()
                c = conn.cursor()
                c.execute('SELECT status, count(*) as count FROM tasks GROUP BY status')
                stats = {row['status']: row['count'] for row in c.fetchall()}
                c.execute('SELECT count(*) as total, sum(file_size) as total_bytes FROM tasks WHERE status="completed"')
                completed_info = c.fetchone()
                c.execute("SELECT worker_id FROM workers WHERE datetime(last_seen) >= datetime('now', '-5 minutes')")
                workers = [r['worker_id'] for r in c.fetchall() if r['worker_id']]
                conn.close()
                
                self._send_json({
                    "paused": is_paused(),
                    "stats": stats,
                    "completed_count": completed_info['total'] or 0,
                    "completed_bytes": completed_info['total_bytes'] or 0,
                    "active_workers": workers
                })
            elif parsed.path == '/api/staging_tasks':
                conn = get_db()
                c = conn.cursor()
                c.execute('SELECT * FROM tasks WHERE status = "downloaded_staging" LIMIT 200')
                tasks = [dict(r) for r in c.fetchall()]
                conn.close()
                self._send_json({"tasks": tasks})
            elif parsed.path == '/api/tasks':
                conn = get_db()
                c = conn.cursor()
                c.execute('SELECT * FROM tasks ORDER BY id DESC LIMIT 100')
                tasks = [dict(r) for r in c.fetchall()]
                conn.close()
                self._send_json({"tasks": tasks})
            else:
                self._send_json({"error": "Not found"}, 404)
        except Exception as e:
            traceback.print_exc()
            self._send_json({"error": str(e)}, 500)

    def do_POST(self):
        try:
            parsed = urllib.parse.urlparse(self.path)
            
            if parsed.path == '/ui/add_url':
                body = self._get_body()
                url = body.get("url", "").strip()
                if url:
                    is_dir = 1 if url.endswith('/') else 0
                    conn = get_db()
                    c = conn.cursor()
                    try:
                        c.execute('INSERT INTO tasks (url, is_dir, status) VALUES (?, ?, "pending")', (url, is_dir))
                        conn.commit()
                    except sqlite3.IntegrityError:
                        pass
                    conn.close()
                self.send_response(303)
                self.send_header('Location', '/ui')
                self.end_headers()
                return

            if not self._check_auth():
                self._send_json({"error": "Unauthorized / Invalid API Key"}, 401)
                return

            body = self._get_body()

            if parsed.path == '/api/queue':
                urls = body.get("urls", [])
                if isinstance(urls, str):
                    urls = [urls]
                parent_url = body.get("parent_url", None)
                added = 0
                conn = get_db()
                c = conn.cursor()
                for u in urls:
                    u = u.strip()
                    if not u:
                        continue
                    is_dir = 1 if u.endswith('/') else 0
                    try:
                        c.execute('''
                            INSERT INTO tasks (url, parent_url, is_dir, status)
                            VALUES (?, ?, ?, 'pending')
                        ''', (u, parent_url, is_dir))
                        added += 1
                    except sqlite3.IntegrityError:
                        pass
                conn.commit()
                conn.close()
                self._send_json({"status": "ok", "added": added})

            elif parsed.path == '/api/claim':
                worker_id = body.get("worker_id", "unknown")
                conn = get_db()

                update_worker_heartbeat(conn, worker_id)

                if is_paused():
                    conn.commit()
                    conn.close()
                    self._send_json({"task": None, "paused": True})
                    return

                c = conn.cursor()
                c.execute('SELECT * FROM tasks WHERE status = "pending" ORDER BY is_dir DESC, id ASC LIMIT 1')
                row = c.fetchone()
                if row:
                    task = dict(row)
                    c.execute('''
                        UPDATE tasks
                        SET status = "assigned", worker_id = ?, attempts = attempts + 1, updated_at = CURRENT_TIMESTAMP
                        WHERE id = ?
                    ''', (worker_id, task['id']))
                    conn.commit()
                    conn.close()
                    self._send_json({"task": task})
                else:
                    conn.commit()
                    conn.close()
                    self._send_json({"task": None})

            elif parsed.path == '/api/report_staging':
                task_id = body.get("task_id")
                worker_id = body.get("worker_id", "unknown")
                staging_path = body.get("staging_path")
                file_size = body.get("file_size", 0)
                file_hash = body.get("file_hash", "")
                discovered_urls = body.get("discovered_urls", [])

                conn = get_db()
                update_worker_heartbeat(conn, worker_id, increment_task=True)

                c = conn.cursor()
                for u in discovered_urls:
                    u = u.strip()
                    if u:
                        is_dir = 1 if u.endswith('/') else 0
                        try:
                            c.execute('INSERT INTO tasks (url, parent_url, is_dir, status) VALUES (?, ?, ?, "pending")',
                                      (u, body.get("url"), is_dir))
                        except sqlite3.IntegrityError:
                            pass

                c.execute('''
                    UPDATE tasks
                    SET status = "downloaded_staging", staging_path = ?, file_size = ?, file_hash = ?, updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                ''', (staging_path, file_size, file_hash, task_id))
                conn.commit()
                conn.close()
                self._send_json({"status": "ok"})

            elif parsed.path == '/api/report_completed':
                task_id = body.get("task_id")
                local_rel_path = body.get("local_rel_path")
                file_size = body.get("file_size", 0)
                file_hash = body.get("file_hash", "")
                conn = get_db()
                c = conn.cursor()
                c.execute('''
                    UPDATE tasks
                    SET status = "completed", local_rel_path = ?, file_size = ?, file_hash = ?, updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                ''', (local_rel_path, file_size, file_hash, task_id))
                conn.commit()
                conn.close()
                self._send_json({"status": "ok"})

            elif parsed.path == '/api/report_failed':
                task_id = body.get("task_id")
                error = body.get("error", "Unknown error")
                conn = get_db()
                c = conn.cursor()
                c.execute('SELECT attempts FROM tasks WHERE id = ?', (task_id,))
                row = c.fetchone()
                attempts = row['attempts'] if row else 1
                new_status = 'failed' if attempts >= 5 else 'pending'
                c.execute('''
                    UPDATE tasks
                    SET status = ?, error_message = ?, updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                ''', (new_status, error, task_id))
                conn.commit()
                conn.close()
                self._send_json({"status": "ok", "new_status": new_status})

            else:
                self._send_json({"error": "Not found"}, 404)
        except Exception as e:
            traceback.print_exc()
            self._send_json({"error": str(e)}, 500)

def run_server(port=8888):
    init_db()
    server_address = ('0.0.0.0', port)
    httpd = ThreadingHTTPServer(server_address, QueueHandler)
    print(f"Queue Coordinator & Management UI running on port {port} with DB {DB_PATH}")
    httpd.serve_forever()

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8888
    run_server(port)
