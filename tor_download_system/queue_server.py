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
            is_vip INTEGER DEFAULT 0,
            vip_added_at TIMESTAMP,
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
    try:
        c.execute('ALTER TABLE tasks ADD COLUMN is_vip INTEGER DEFAULT 0')
    except sqlite3.OperationalError:
        pass
    try:
        c.execute('ALTER TABLE tasks ADD COLUMN vip_added_at TIMESTAMP')
    except sqlite3.OperationalError:
        pass

    c.execute('''
        CREATE TABLE IF NOT EXISTS workers (
            worker_id TEXT PRIMARY KEY,
            last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            tasks_completed INTEGER DEFAULT 0
        )
    ''')
    c.execute('CREATE INDEX IF NOT EXISTS idx_status ON tasks(status)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_url ON tasks(url)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_vip ON tasks(is_vip, vip_added_at)')
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

def extract_relative_path(url):
    parsed = urllib.parse.urlparse(url)
    path = urllib.parse.unquote(parsed.path)
    return path if path else url

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tor Download Manager & Explorer — Wieselburg</title>
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
            --vip-gold: #fbbf24;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Inter', sans-serif;
            background-color: var(--bg-color);
            color: var(--text-main);
            padding: 24px;
            line-height: 1.5;
        }
        .container { max-width: 1280px; margin: 0 auto; }
        header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 24px;
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
            padding: 8px 14px;
            border-radius: 6px;
            cursor: pointer;
            font-weight: 500;
            font-size: 13px;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }
        .btn:hover { background: var(--border-color); }
        .btn-pause { background: rgba(245, 158, 11, 0.2); color: var(--warning); border-color: var(--warning); }
        .btn-resume { background: rgba(16, 185, 129, 0.2); color: var(--success); border-color: var(--success); }
        .btn-vip { background: rgba(251, 191, 36, 0.2); color: var(--vip-gold); border-color: var(--vip-gold); font-size: 11px; padding: 4px 8px; }
        .btn-vip-cancel { background: rgba(156, 163, 175, 0.2); color: var(--text-muted); border-color: var(--border-color); font-size: 11px; padding: 4px 8px; }
        .btn-cancel { background: rgba(239, 68, 68, 0.2); color: var(--danger); border-color: var(--danger); font-size: 11px; padding: 4px 8px; }

        .grid-stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }
        .stat-card {
            background: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 18px;
        }
        .stat-label { font-size: 12px; color: var(--text-muted); margin-bottom: 4px; font-weight: 500; text-transform: uppercase; letter-spacing: 0.05em; }
        .stat-value { font-size: 24px; font-weight: 700; color: #fff; }
        .stat-sub { font-size: 12px; color: var(--text-muted); margin-top: 4px; }
        
        .nav-tabs { display: flex; gap: 12px; margin-bottom: 20px; border-bottom: 1px solid var(--border-color); padding-bottom: 10px; }
        .tab { padding: 8px 16px; font-weight: 600; font-size: 14px; border-radius: 6px; cursor: pointer; color: var(--text-muted); text-decoration: none; }
        .tab.active { background: var(--primary); color: #fff; }

        .card {
            background: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 24px;
        }
        .section-title { font-size: 16px; font-weight: 600; margin-bottom: 14px; color: #fff; display: flex; justify-content: space-between; align-items: center; }
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
        th, td { padding: 10px 14px; text-align: left; border-bottom: 1px solid var(--border-color); font-size: 13px; }
        th { background: rgba(0,0,0,0.25); color: var(--text-muted); font-weight: 600; text-transform: uppercase; font-size: 11px; letter-spacing: 0.05em; }
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
        .badge-vip { background: rgba(251, 191, 36, 0.25); color: var(--vip-gold); border: 1px solid var(--vip-gold); }
        .badge-assigned { background: rgba(59, 130, 246, 0.15); color: var(--primary); }
        .badge-staging { background: rgba(16, 185, 129, 0.15); color: #34d399; }
        .badge-completed { background: rgba(16, 185, 129, 0.25); color: var(--success); }
        .badge-failed { background: rgba(239, 68, 68, 0.2); color: var(--danger); }
        
        .path-cell { font-family: monospace; font-size: 12px; word-break: break-all; color: var(--text-main); }
        .explorer-tree { font-family: monospace; font-size: 13px; }
        .tree-item { padding: 8px 12px; border-bottom: 1px solid rgba(255,255,255,0.03); display: flex; align-items: center; justify-content: space-between; }
        .tree-item:hover { background: rgba(255,255,255,0.03); }
        .tree-name { display: flex; align-items: center; gap: 8px; }
        .search-box { margin-bottom: 16px; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div>
                <h1>Tor Download Manager & Explorer STATUS_BADGE</h1>
                <div class="subtitle">Wieselburg Coordinator & Priority Hub</div>
            </div>
            <div class="actions">
                PAUSE_RESUME_BTN
                <button class="btn" onclick="location.reload()">Refresh (F5)</button>
            </div>
        </header>

        <div class="grid-stats">
            <div class="stat-card">
                <div class="stat-label">VIP Queue (Priority)</div>
                <div class="stat-value" style="color: var(--vip-gold)">VIP_TASKS</div>
                <div class="stat-sub">High-priority items</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Pending Queue</div>
                <div class="stat-value" style="color: var(--warning)">PENDING_TASKS</div>
                <div class="stat-sub">Standard priority</div>
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

        <div class="nav-tabs">
            <a href="/ui?view=queue" class="tab TAB_QUEUE_ACTIVE">Active Queue & VIP List</a>
            <a href="/ui?view=explorer" class="tab TAB_EXPLORER_ACTIVE">File & Folder Explorer</a>
        </div>

        VIEW_CONTENT

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
            params = urllib.parse.parse_qs(parsed.query)
            view = params.get("view", ["queue"])[0]

            if parsed.path == '/ui/toggle_pause':
                set_paused(not is_paused())
                self.send_response(303)
                self.send_header('Location', '/ui')
                self.end_headers()
                return

            if parsed.path in ('/ui/set_vip', '/ui/cancel_vip', '/ui/cancel_task'):
                task_id = params.get("id", [""])[0]
                target_url = params.get("url", [""])[0]
                folder_path = params.get("folder", [""])[0]
                conn = get_db()
                c = conn.cursor()

                if parsed.path == '/ui/set_vip':
                    if task_id:
                        c.execute("UPDATE tasks SET is_vip = 1, vip_added_at = CURRENT_TIMESTAMP WHERE id = ?", (task_id,))
                    elif target_url:
                        c.execute("UPDATE tasks SET is_vip = 1, vip_added_at = CURRENT_TIMESTAMP WHERE url = ? OR url LIKE ? OR parent_url LIKE ?", (target_url, f"{target_url}%", f"{target_url}%"))
                    elif folder_path:
                        c.execute("UPDATE tasks SET is_vip = 1, vip_added_at = CURRENT_TIMESTAMP WHERE url LIKE ? AND status IN ('pending', 'assigned')", (f"%{folder_path}%",))
                elif parsed.path == '/ui/cancel_vip':
                    if task_id:
                        c.execute("UPDATE tasks SET is_vip = 0, vip_added_at = NULL WHERE id = ?", (task_id,))
                    elif target_url:
                        c.execute("UPDATE tasks SET is_vip = 0, vip_added_at = NULL WHERE url = ? OR url LIKE ? OR parent_url LIKE ?", (target_url, f"{target_url}%", f"{target_url}%"))
                    elif folder_path:
                        c.execute("UPDATE tasks SET is_vip = 0, vip_added_at = NULL WHERE url LIKE ?", (f"%{folder_path}%",))
                elif parsed.path == '/ui/cancel_task':
                    if task_id:
                        c.execute("SELECT url, is_dir FROM tasks WHERE id = ?", (task_id,))
                        row = c.fetchone()
                        if row:
                            c.execute("DELETE FROM tasks WHERE id = ?", (task_id,))
                            if row['is_dir']:
                                dir_url = row['url']
                                c.execute("DELETE FROM tasks WHERE url LIKE ? OR parent_url LIKE ?", (f"{dir_url}%", f"{dir_url}%"))
                    elif target_url:
                        c.execute("DELETE FROM tasks WHERE url = ? OR url LIKE ? OR parent_url LIKE ?", (target_url, f"{target_url}%", f"{target_url}%"))
                    elif folder_path:
                        c.execute("DELETE FROM tasks WHERE url LIKE ?", (f"%{folder_path}%",))

                conn.commit()
                conn.close()
                redirect_url = '/ui?view=explorer' if 'view=explorer' in self.headers.get('Referer', '') else f'/ui?view={view}'
                self.send_response(303)
                self.send_header('Location', redirect_url)
                self.end_headers()
                return

            if parsed.path in ('/', '/ui'):
                conn = get_db()
                c = conn.cursor()

                c.execute('SELECT status, count(*) as count FROM tasks GROUP BY status')
                stats = {row['status']: row['count'] for row in c.fetchall()}

                c.execute('SELECT count(*) as count FROM tasks WHERE is_vip = 1 AND status = "pending"')
                vip_count = c.fetchone()['count']
                
                c.execute('SELECT count(*) as total, sum(file_size) as total_bytes FROM tasks WHERE status="completed"')
                completed_info = c.fetchone()
                
                c.execute("SELECT worker_id FROM workers WHERE datetime(last_seen) >= datetime('now', '-5 minutes')")
                workers = [r['worker_id'] for r in c.fetchall() if r['worker_id']]

                c.execute('SELECT count(*) as count FROM tasks')
                total_tasks = c.fetchone()['count']

                comp_bytes = completed_info['total_bytes'] or 0
                if comp_bytes > 1073741824:
                    comp_size_str = f"{comp_bytes / 1073741824:.2f} GB"
                else:
                    comp_size_str = f"{comp_bytes / 1048576:.1f} MB"

                if view == 'explorer':
                    search_q = params.get("q", [""])[0].strip()
                    if search_q:
                        c.execute("SELECT * FROM tasks WHERE url LIKE ? ORDER BY is_dir DESC, url ASC LIMIT 150", (f"%{search_q}%",))
                    else:
                        c.execute("SELECT * FROM tasks ORDER BY is_dir DESC, url ASC LIMIT 150")
                    
                    items = [dict(r) for r in c.fetchall()]
                    conn.close()

                    explorer_html = f"""
                    <div class="card">
                        <div class="section-title">
                            File & Directory Explorer
                            <span style="font-size: 13px; font-weight: normal; color: var(--text-muted);">Browse cataloged files & directories; promote or delete branches</span>
                        </div>
                        <form method="GET" action="/ui" class="search-box">
                            <input type="hidden" name="view" value="explorer" />
                            <div style="display: flex; gap: 10px;">
                                <input type="text" name="q" value="{search_q}" placeholder="Filter by folder or file name (e.g. ALSGLOBAL/03 Metallurgy/)..." />
                                <button type="submit" class="btn-submit">Search Explorer</button>
                            </div>
                        </form>
                        <div class="explorer-tree">
                    """
                    for item in items:
                        rel = extract_relative_path(item['url'])
                        icon = "📁" if item['is_dir'] else "📄"
                        badge = "VIP Pending" if (item['is_vip'] and item['status'] == 'pending') else item['status']
                        badge_cls = "badge-vip" if (item['is_vip'] and item['status'] == 'pending') else f"badge-{item['status']}"
                        
                        enc_url = urllib.parse.quote(item['url'])
                        vip_btn = f'<a href="/ui/set_vip?url={enc_url}" class="btn btn-vip">★ VIP</a>' if not item['is_vip'] else f'<a href="/ui/cancel_vip?url={enc_url}" class="btn btn-vip-cancel">☆ Normal</a>'
                        cancel_label = "✖ Remove Folder" if item['is_dir'] else "✖ Remove File"
                        cancel_btn = f'<a href="/ui/cancel_task?url={enc_url}" class="btn btn-cancel">{cancel_label}</a>'

                        explorer_html += f"""
                        <div class="tree-item">
                            <div class="tree-name">
                                <span>{icon}</span>
                                <span class="path-cell" title="{item['url']}">{rel}</span>
                            </div>
                            <div style="display: flex; gap: 8px; align-items: center;">
                                <span class="badge {badge_cls}">{badge}</span>
                                <span style="font-size: 12px; color: var(--text-muted); width: 80px; text-align: right;">{item['file_size']} B</span>
                                {vip_btn}
                                {cancel_btn}
                            </div>
                        </div>
                        """
                    explorer_html += "</div></div>"
                    view_content = explorer_html

                else:
                    c.execute('SELECT * FROM tasks WHERE status IN ("pending", "assigned") ORDER BY is_vip DESC, vip_added_at ASC, id ASC LIMIT 100')
                    active_queue = [dict(r) for r in c.fetchall()]
                    conn.close()

                    queue_rows = ""
                    for t in active_queue:
                        rel = extract_relative_path(t['url'])
                        badge = "VIP Pending" if (t['is_vip'] and t['status'] == 'pending') else t['status']
                        badge_cls = "badge-vip" if (t['is_vip'] and t['status'] == 'pending') else f"badge-{t['status']}"
                        worker_str = t['worker_id'] or "-"
                        size_str = f"{t['file_size']} B" if t['file_size'] else "-"

                        enc_url = urllib.parse.quote(t['url'])
                        vip_action = f'<a href="/ui/cancel_vip?id={t["id"]}" class="btn btn-vip-cancel">☆ Normal</a>' if t['is_vip'] else f'<a href="/ui/set_vip?id={t["id"]}" class="btn btn-vip">★ VIP</a>'
                        cancel_action = f'<a href="/ui/cancel_task?id={t["id"]}" class="btn btn-cancel">✖ Remove</a>'

                        queue_rows += f"""<tr>
                            <td>{t['id']}</td>
                            <td class="path-cell" title="{t['url']}">{rel}</td>
                            <td><span class="badge {badge_cls}">{badge}</span></td>
                            <td>{worker_str}</td>
                            <td>{size_str}</td>
                            <td style="display: flex; gap: 6px;">{vip_action}{cancel_action}</td>
                        </tr>"""

                    queue_html = f"""
                    <div class="card">
                        <div class="section-title">Seed New Onion Target</div>
                        <form class="seed-form" method="POST" action="/ui/add_url">
                            <input type="text" name="url" placeholder="http://xxxxxxxx.onion/data/ALSGLOBAL/subfolder/" required />
                            <button type="submit" class="btn-submit">Add Target URL</button>
                        </form>
                    </div>

                    <div class="card">
                        <div class="section-title">
                            Active Queue (VIP First)
                            <span style="font-size: 12px; color: var(--text-muted);">VIP items are downloaded first in order of VIP declaration</span>
                        </div>
                        <table>
                            <thead>
                                <tr>
                                    <th>ID</th>
                                    <th>Path (After .onion)</th>
                                    <th>Status</th>
                                    <th>Worker</th>
                                    <th>Size</th>
                                    <th>Priority & Actions</th>
                                </tr>
                            </thead>
                            <tbody>
                                {queue_rows if queue_rows else '<tr><td colspan="6" style="text-align: center; color: var(--text-muted);">No active pending or VIP tasks in queue.</td></tr>'}
                            </tbody>
                        </table>
                    </div>
                    """
                    view_content = queue_html

                paused = is_paused()
                status_badge = '<span class="badge badge-failed" style="margin-left: 8px;">PAUSED</span>' if paused else '<span class="badge badge-completed" style="margin-left: 8px;">ACTIVE</span>'
                pause_btn = '<a href="/ui/toggle_pause" class="btn btn-resume">Resume Queue</a>' if paused else '<a href="/ui/toggle_pause" class="btn btn-pause">Pause Queue</a>'

                html = HTML_TEMPLATE
                html = html.replace("STATUS_BADGE", status_badge)
                html = html.replace("PAUSE_RESUME_BTN", pause_btn)
                html = html.replace("VIP_TASKS", f"{vip_count:,}")
                html = html.replace("PENDING_TASKS", f"{stats.get('pending', 0):,}")
                html = html.replace("COMPLETED_SIZE", comp_size_str)
                html = html.replace("COMPLETED_COUNT", f"{completed_info['total'] or 0:,}")
                html = html.replace("ACTIVE_WORKERS", str(len(workers)))
                html = html.replace("WORKER_NAMES", ", ".join(workers) if workers else "None active in last 5m")
                html = html.replace("TAB_QUEUE_ACTIVE", "active" if view == "queue" else "")
                html = html.replace("TAB_EXPLORER_ACTIVE", "active" if view == "explorer" else "")
                html = html.replace("VIEW_CONTENT", view_content)

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
                c.execute('SELECT * FROM tasks WHERE status = "pending" ORDER BY is_vip DESC, vip_added_at ASC, is_dir DESC, id ASC LIMIT 1')
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
