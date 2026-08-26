#!/usr/bin/env python3
import sqlite3
import json
import time
import os
import sys
import threading
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
    conn = sqlite3.connect(DB_PATH, timeout=60.0, isolation_level=None)
    conn.execute("PRAGMA busy_timeout = 60000;")
    conn.execute("PRAGMA synchronous = NORMAL;")
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH, timeout=60.0, isolation_level=None)
    conn.execute("PRAGMA journal_mode = WAL;")
    conn.execute("PRAGMA synchronous = NORMAL;")
    conn.execute("PRAGMA wal_autocheckpoint = 1000;")
    conn.row_factory = sqlite3.Row

    # Startup integrity and crash-recovery verification
    try:
        cur = conn.cursor()
        cur.execute("PRAGMA quick_check;")
        check_res = cur.fetchone()[0]
        if check_res != "ok":
            print(f"[DB] Integrity check returned: {check_res}. Running checkpoint recovery...")
            cur.execute("PRAGMA wal_checkpoint(TRUNCATE);")
    except Exception as e:
        print(f"[DB] Startup recovery exception: {e}")

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
        CREATE TABLE IF NOT EXISTS stats_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            return_code INTEGER,
            speed_bps REAL,
            file_size INTEGER,
            worker_id TEXT
        )
    ''')
    c.execute('CREATE INDEX IF NOT EXISTS idx_stats_time ON stats_log(timestamp)')

    c.execute('''
        CREATE TABLE IF NOT EXISTS workers (
            worker_id TEXT PRIMARY KEY,
            last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            tasks_completed INTEGER DEFAULT 0
        )
    ''')
    c.execute('CREATE INDEX IF NOT EXISTS idx_claim ON tasks(status, is_vip DESC, id ASC)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_status ON tasks(status)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_parent ON tasks(parent_url)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_assigned ON tasks(status, updated_at)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_url ON tasks(url)')
DB_WRITE_LOCK = threading.Lock()
WORKERS_LOCK = threading.Lock()
WORKERS_MAP = {}

def update_worker_heartbeat(worker_id, increment_task=False):
    if not worker_id:
        return
    now = time.time()
    with WORKERS_LOCK:
        if worker_id not in WORKERS_MAP:
            WORKERS_MAP[worker_id] = {"last_seen": now, "tasks_completed": 0}
        w = WORKERS_MAP[worker_id]
        w["last_seen"] = now
        if increment_task:
            w["tasks_completed"] += 1

def get_active_workers(within_seconds=300):
    cutoff = time.time() - within_seconds
    with WORKERS_LOCK:
        return [wid for wid, info in WORKERS_MAP.items() if info["last_seen"] >= cutoff]

def extract_relative_path(url):
    parsed = urllib.parse.urlparse(url)
    path = urllib.parse.unquote(parsed.path)
    return path if path else url

def build_tree_structure(tasks):
    root = {"name": "root", "is_dir": True, "children": {}, "task": None}
    for t in tasks:
        parsed = urllib.parse.urlparse(t['url'])
        clean_path = urllib.parse.unquote(parsed.path).strip('/')
        if not clean_path:
            continue
        parts = clean_path.split('/')
        curr = root
        for i, part in enumerate(parts):
            if part not in curr["children"]:
                curr["children"][part] = {
                    "name": part,
                    "is_dir": (i < len(parts) - 1) or bool(t['is_dir']),
                    "children": {},
                    "task": None
                }
            curr = curr["children"][part]
            if i == len(parts) - 1:
                curr["task"] = t
                curr["is_dir"] = bool(t['is_dir'])
    return root

def compute_node_rollup_status(node):
    if not node["is_dir"]:
        t = node["task"]
        if t:
            return t["status"], bool(t.get("is_vip"))
        return "completed", False

    child_statuses = []
    has_vip = False

    for child_name, child_node in node["children"].items():
        st, vip = compute_node_rollup_status(child_node)
        child_statuses.append(st)
        if vip:
            has_vip = True

    if not child_statuses:
        return "completed", False

    if "failed" in child_statuses:
        return "failed", False
    if "pending" in child_statuses or "VIP Pending" in child_statuses:
        return ("VIP Pending" if has_vip else "pending"), has_vip
    if "assigned" in child_statuses:
        return "assigned", False
    if "downloaded_staging" in child_statuses:
        return "downloaded_staging", False
    if all(s == "completed" for s in child_statuses):
        return "completed", False

    return "pending", False

def human_size(num):
    if not num: return ""
    num = float(num)
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if num < 1024.0:
            if unit == 'B': return f"{int(num)} B"
            return f"{num:.1f} {unit}"
        num /= 1024.0
    return f"{num:.1f} PB"

def render_tree_node(node, depth=0, path=""):
    html = ""
    sorted_keys = sorted(node["children"].keys(), key=lambda k: (not node["children"][k]["is_dir"], k.lower()))
    for key in sorted_keys:
        child = node["children"][key]
        item_name = child["name"]
        task = child["task"]

        badge_html = ""
        action_html = ""
        size_str = ""

        if child["is_dir"]:
            rollup_st, is_vip_rollup = compute_node_rollup_status(child)
            badge_cls = "badge-vip" if (rollup_st == "VIP Pending") else f"badge-{rollup_st}"
            badge_html = f'<span class="badge {badge_cls}">{rollup_st}</span>'

            dir_url = task['url'] if task else ""
            if dir_url:
                enc_url = urllib.parse.quote(dir_url)
                rescan_btn = f'<a href="/ui/rescan_dir?url={enc_url}" class="btn" style="background:rgba(14,165,233,0.2);color:#38bdf8;border-color:#38bdf8;font-size:11px;padding:4px 8px;">🔄 Rescan Folder</a>'
                vip_btn = f'<a href="/ui/set_vip?url={enc_url}" class="btn btn-vip">★ VIP Folder</a>'
                cancel_btn = f'<a href="/ui/cancel_task?url={enc_url}" class="btn btn-cancel">✖ Remove Folder</a>'
                action_html = f'{rescan_btn} {vip_btn} {cancel_btn}'

            child_path = path + "/" + item_name
            inner_content = render_tree_node(child, depth + 1, child_path)
            html += f"""
            <details class="tree-folder" data-path="{urllib.parse.quote(child_path)}">
                <summary class="tree-summary">
                    <span class="folder-title">📁 {item_name}/</span>
                    <div class="tree-actions">{badge_html} {action_html}</div>
                </summary>
                <div class="tree-children">
                    {inner_content if inner_content else '<div class="empty-folder">(Empty folder)</div>'}
                </div>
            </details>
            """
        else:
            if task:
                badge = "VIP Pending" if (task['is_vip'] and task['status'] == 'pending') else task['status']
                badge_cls = "badge-vip" if (task['is_vip'] and task['status'] == 'pending') else f"badge-{task['status']}"
                badge_html = f'<span class="badge {badge_cls}">{badge}</span>'
                size_str = human_size(task['file_size']) if task['file_size'] else ""
                enc_url = urllib.parse.quote(task['url'])

                vip_btn = f'<a href="/ui/set_vip?url={enc_url}" class="btn btn-vip">★ VIP</a>' if not task['is_vip'] else f'<a href="/ui/cancel_vip?url={enc_url}" class="btn btn-vip-cancel">☆ Normal</a>'
                cancel_btn = f'<a href="/ui/cancel_task?url={enc_url}" class="btn btn-cancel">✖ Remove File</a>'
                action_html = f'{vip_btn} {cancel_btn}'

            html += f"""
            <div class="tree-file">
                <span class="file-title">📄 {item_name}</span>
                <div class="tree-actions">
                    <span style="font-size: 12px; color: var(--text-muted); margin-right: 8px;">{size_str}</span>
                    {badge_html}
                    {action_html}
                </div>
            </div>
            """
    return html

METRICS_CACHE = {"timestamp": 0, "result": ("Idle", "Calculating...", 0.0, 0.0)}
METRICS_LOCK = threading.Lock()

def calculate_speed_and_etc(conn):
    now = time.time()
    with METRICS_LOCK:
        if now - METRICS_CACHE["timestamp"] < 5.0:
            return METRICS_CACHE["result"]

    c = conn.cursor()
    c.execute("""
        SELECT SUM(file_size) as recent_bytes, COUNT(*) as recent_tasks
        FROM tasks 
        WHERE status IN ('downloaded_staging', 'completed') 
          AND datetime(updated_at) >= datetime('now', '-10 minutes')
    """)
    rec_row = c.fetchone()
    recent_bytes = rec_row['recent_bytes'] or 0
    recent_tasks = rec_row['recent_tasks'] or 0

    speed_bps = recent_bytes / 600.0
    tasks_per_sec = recent_tasks / 600.0

    c.execute("""
        SELECT SUM(file_size) as known_bytes, COUNT(*) as total_pending
        FROM tasks 
        WHERE status IN ('pending', 'assigned')
    """)
    p_info = c.fetchone()
    known_remaining = p_info['known_bytes'] or 0
    total_pending = p_info['total_pending'] or 0

    c.execute("""
        SELECT AVG(file_size) as avg_bytes
        FROM tasks
        WHERE status = 'completed' AND is_dir = 0 AND file_size > 0
    """)
    avg_row = c.fetchone()
    avg_size = avg_row['avg_bytes'] if (avg_row and avg_row['avg_bytes']) else 500000

    c.execute("""
        SELECT COUNT(*) as unk_count
        FROM tasks
        WHERE status IN ('pending', 'assigned') AND is_dir = 0 AND (file_size IS NULL OR file_size = 0)
    """)
    unk_count = c.fetchone()['unk_count'] or 0

    est_remaining_bytes = known_remaining + (unk_count * avg_size)

    if speed_bps >= 1048576:
        speed_str = f"{speed_bps / 1048576:.2f} MB/s"
    elif speed_bps >= 1024:
        speed_str = f"{speed_bps / 1024:.1f} KB/s"
    elif tasks_per_sec > 0:
        speed_str = f"{tasks_per_sec:.1f} items/s"
    elif speed_bps > 0:
        speed_str = f"{speed_bps:.0f} B/s"
    else:
        speed_str = "Idle"

    if total_pending == 0:
        etc_str = "Completed"
    elif speed_bps >= 1024:
        seconds_left = int(est_remaining_bytes / speed_bps)
        if seconds_left < 60:
            etc_str = f"{seconds_left}s"
        elif seconds_left < 3600:
            etc_str = f"{seconds_left // 60}m {seconds_left % 60}s"
        elif seconds_left < 86400:
            hours = seconds_left // 3600
            mins = (seconds_left % 3600) // 60
            etc_str = f"{hours}h {mins}m"
        else:
            days = seconds_left // 86400
            hours = (seconds_left % 86400) // 3600
            etc_str = f"{days}d {hours}h"
    elif tasks_per_sec > 0:
        seconds_left = int(total_pending / tasks_per_sec)
        if seconds_left < 60:
            etc_str = f"{seconds_left}s"
        elif seconds_left < 3600:
            etc_str = f"{seconds_left // 60}m {seconds_left % 60}s"
        elif seconds_left < 86400:
            hours = seconds_left // 3600
            mins = (seconds_left % 3600) // 60
            etc_str = f"{hours}h {mins}m"
        else:
            days = seconds_left // 86400
            hours = (seconds_left % 86400) // 3600
            etc_str = f"{days}d {hours}h"
    else:
        etc_str = "Calculating..."

    result = (speed_str, etc_str, speed_bps, est_remaining_bytes)
    with METRICS_LOCK:
        METRICS_CACHE["timestamp"] = now
        METRICS_CACHE["result"] = result
    return result

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
        .btn-retry { background: rgba(59, 130, 246, 0.2); color: var(--primary); border-color: var(--primary); }
        .btn-vip { background: rgba(251, 191, 36, 0.2); color: var(--vip-gold); border-color: var(--vip-gold); font-size: 11px; padding: 4px 8px; }
        .btn-vip-cancel { background: rgba(156, 163, 175, 0.2); color: var(--text-muted); border-color: var(--border-color); font-size: 11px; padding: 4px 8px; }
        .btn-cancel { background: rgba(239, 68, 68, 0.2); color: var(--danger); border-color: var(--danger); font-size: 11px; padding: 4px 8px; }

        .grid-stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }
        .stat-card {
            background: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 18px;
        }
        .stat-label { font-size: 11px; color: var(--text-muted); margin-bottom: 4px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; }
        .stat-value { font-size: 22px; font-weight: 700; color: #fff; }
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
        
        /* Foldable Tree Explorer Styles */
        .tree-container { font-family: monospace; font-size: 13px; }
        .tree-folder { margin-bottom: 4px; border-left: 2px solid var(--border-color); padding-left: 10px; margin-left: 6px; }
        .tree-summary {
            cursor: pointer;
            padding: 8px 12px;
            background: rgba(255,255,255,0.02);
            border-radius: 6px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            user-select: none;
        }
        .tree-summary:hover { background: rgba(255,255,255,0.05); }
        .folder-title { font-weight: 600; color: #facc15; }
        .tree-children { padding-left: 12px; margin-top: 4px; }
        .tree-file {
            padding: 6px 12px;
            margin: 2px 0;
            border-radius: 4px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            background: rgba(0,0,0,0.15);
        }
        .tree-file:hover { background: rgba(255,255,255,0.03); }
        .file-title { color: #e2e8f0; word-break: break-all; }
        .tree-actions { display: flex; gap: 8px; align-items: center; }
        .empty-folder { font-size: 12px; color: var(--text-muted); padding: 4px 12px; font-style: italic; }
        .search-box { margin-bottom: 16px; }
    </style>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <div class="container">
        <header>
            <div>
                <h1>Tor Download Manager & Explorer STATUS_BADGE</h1>
                <div class="subtitle">Wieselburg Coordinator & Priority Hub</div>
            </div>
            <div class="actions">
                RETRY_FAILED_BTN
                <a href="/ui/rescan_empty_dirs" class="btn" style="background:rgba(14,165,233,0.2);color:#38bdf8;border-color:#38bdf8;">🔄 Rescan Empty Folders</a>
                PAUSE_RESUME_BTN
                <button class="btn" onclick="location.reload()">Refresh (F5)</button>
            </div>
        </header>

        <div class="grid-stats">
            <div class="stat-card">
                <div class="stat-label">Download Speed</div>
                <div class="stat-value" style="color: #38bdf8">DOWNLOAD_SPEED</div>
                <div class="stat-sub">Aggregate streams</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Estimated Time (ETC)</div>
                <div class="stat-value" style="color: #a78bfa">ETC_TIME</div>
                <div class="stat-sub">Remaining queue</div>
            </div>
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
                <div class="stat-label">Remaining Payload</div>
                <div class="stat-value" style="color: #f472b6">REMAINING_SIZE</div>
                <div class="stat-sub">Estimated pending bytes</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Completion %</div>
                <div class="stat-value" style="color: #4ade80">COMPLETION_PERCENT%</div>
                <div class="stat-sub">By data size</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Active Worker Streams</div>
                <div class="stat-value" style="color: var(--primary)">ACTIVE_WORKERS</div>
                <div class="stat-sub">Active streams (last 5m)</div>
            </div>
        </div>

        THROTTLING_WARNING
        <div class="nav-tabs">
            <a href="/ui?view=queue" class="tab TAB_QUEUE_ACTIVE">Active Queue & VIP List</a>
            <a href="/ui?view=explorer" class="tab TAB_EXPLORER_ACTIVE">Collapsible File Explorer</a>
            <a href="/ui?view=advanced" class="tab TAB_ADVANCED_ACTIVE">Advanced Statistics</a>
        </div>

        VIEW_CONTENT

        <script>
            document.addEventListener("DOMContentLoaded", () => {
                const details = document.querySelectorAll("details.tree-folder");
                details.forEach(el => {
                    const id = "tree-node-" + el.getAttribute("data-path");
                    if (localStorage.getItem(id) === "true") {
                        el.setAttribute("open", "");
                    }
                    el.addEventListener("toggle", () => {
                        localStorage.setItem(id, el.hasAttribute("open"));
                    });
                });
            });
        </script>
    </div>
</body>
</html>
"""

class QueueHandler(BaseHTTPRequestHandler):
    def _send_json(self, data, code=200):
        try:
            body = json.dumps(data).encode('utf-8')
            self.send_response(code)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Connection', 'close')
            self.end_headers()
            self.wfile.write(body)
            self.wfile.flush()
        except Exception:
            pass

    def _send_html(self, html_content, code=200):
        try:
            body = html_content.encode('utf-8')
            self.send_response(code)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Connection', 'close')
            self.end_headers()
            self.wfile.write(body)
            self.wfile.flush()
        except Exception:
            pass

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
            if parsed.path == '/ui/mobile':
                view = 'mobile'

            if parsed.path == '/ui/toggle_pause':
                set_paused(not is_paused())
                self.send_response(303)
                self.send_header('Location', '/ui')
                self.end_headers()
                return

            if parsed.path == '/ui/retry_failed':
                with DB_WRITE_LOCK:
                    conn = get_db()
                    c = conn.cursor()
                    c.execute("UPDATE tasks SET status = 'pending', attempts = 0, error_message = NULL WHERE status = 'failed'")
                    conn.commit()
                    conn.close()
                redirect_url = self.headers.get('Referer', '/ui')
                self.send_response(303)
                self.send_header('Location', redirect_url)
                self.end_headers()
                return

            if parsed.path == '/ui/clear_all':
                with DB_WRITE_LOCK:
                    conn = get_db()
                    c = conn.cursor()
                    c.execute("DELETE FROM tasks")
                    c.execute("DELETE FROM workers")
                    c.execute("VACUUM")
                    conn.commit()
                    conn.close()
                self.send_response(303)
                self.send_header('Location', '/ui')
                self.end_headers()
                return

            if parsed.path in ('/ui/rescan_dir', '/ui/rescan_empty_dirs'):
                target_url = params.get("url", [""])[0]
                task_id = params.get("id", [""])[0]
                with DB_WRITE_LOCK:
                    conn = get_db()
                    c = conn.cursor()
                    if parsed.path == '/ui/rescan_empty_dirs':
                        c.execute("""
                            UPDATE tasks
                            SET status = 'pending', attempts = 0, is_dir = 1, is_vip = 1, error_message = NULL
                            WHERE is_dir = 1 AND url NOT IN (
                                SELECT DISTINCT parent_url FROM tasks WHERE parent_url IS NOT NULL
                            )
                        """)
                    elif task_id:
                        c.execute("UPDATE tasks SET status = 'pending', is_dir = 1, attempts = 0, is_vip = 1, error_message = NULL WHERE id = ?", (task_id,))
                    elif target_url:
                        c.execute("UPDATE tasks SET status = 'pending', is_dir = 1, attempts = 0, is_vip = 1, error_message = NULL WHERE url = ? OR url = ?", (target_url, target_url.rstrip('/') + '/'))
                    conn.commit()
                    conn.close()
                redirect_url = '/ui?view=explorer' if 'view=explorer' in self.headers.get('Referer', '') else f'/ui?view={view}'
                self.send_response(303)
                self.send_header('Location', redirect_url)
                self.end_headers()
                return

            if parsed.path in ('/ui/set_vip', '/ui/cancel_vip', '/ui/cancel_task'):
                task_id = params.get("id", [""])[0]
                target_url = params.get("url", [""])[0]
                folder_path = params.get("folder", [""])[0]
                with DB_WRITE_LOCK:
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
                try:
                    c = conn.cursor()

                    c.execute('SELECT status, count(*) as count FROM tasks GROUP BY status')
                    stats = {row['status']: row['count'] for row in c.fetchall()}

                    c.execute('SELECT count(*) as count FROM tasks WHERE is_vip = 1 AND status = "pending"')
                    vip_count = c.fetchone()['count']
                    
                    c.execute('SELECT count(*) as total, sum(file_size) as total_bytes FROM tasks WHERE status="completed"')
                    completed_info = c.fetchone()
                    
                    workers = get_active_workers(300)

                    speed_str, etc_str, speed_bps, est_rem_bytes = calculate_speed_and_etc(conn)

                    c.execute('SELECT count(*) as count FROM tasks')
                    total_tasks = c.fetchone()['count']

                    failed_count = stats.get('failed', 0)
                    retry_failed_btn = f'<a href="/ui/retry_failed" class="btn btn-retry">🔄 Retry Failed ({failed_count})</a>' if failed_count > 0 else ''

                    comp_bytes = completed_info['total_bytes'] or 0
                    if comp_bytes > 1073741824:
                        comp_size_str = f"{comp_bytes / 1073741824:.2f} GB"
                    else:
                        comp_size_str = f"{comp_bytes / 1048576:.1f} MB"

                    
                    if view == 'advanced':
                        c.execute('''
                            SELECT 
                                strftime('%Y-%m-%d %H:%M:00', timestamp) as minute,
                                COUNT(*) as requests,
                                SUM(CASE WHEN return_code = 200 THEN 1 ELSE 0 END) as rc_200,
                                SUM(CASE WHEN return_code = 429 THEN 1 ELSE 0 END) as rc_429,
                                SUM(CASE WHEN return_code = 500 THEN 1 ELSE 0 END) as rc_500,
                                SUM(CASE WHEN return_code NOT IN (200, 429, 500) THEN 1 ELSE 0 END) as rc_other,
                                SUM(speed_bps) as sum_speed_bps
                            FROM stats_log
                            WHERE datetime(timestamp) >= datetime('now', '-1 hour')
                              AND datetime(timestamp) <= datetime('now', '-1 minute')
                            GROUP BY minute
                            ORDER BY minute ASC
                        ''')
                        timeline_data = [dict(r) for r in c.fetchall()]

                        c.execute('''
                            SELECT speed_bps FROM stats_log 
                            WHERE speed_bps > 0 AND datetime(timestamp) >= datetime('now', '-1 hour')
                            ORDER BY speed_bps ASC
                        ''')
                        speeds = [r['speed_bps'] for r in c.fetchall()]
                        speed_min = speeds[0] if speeds else 0
                        speed_max = speeds[-1] if speeds else 0
                        speed_avg = sum(speeds)/len(speeds) if speeds else 0
                        speed_median = speeds[len(speeds)//2] if speeds else 0

                        c.execute('''
                            SELECT file_size FROM stats_log 
                            WHERE file_size > 0 AND datetime(timestamp) >= datetime('now', '-1 hour')
                            ORDER BY file_size ASC
                        ''')
                        sizes = [r['file_size'] for r in c.fetchall()]
                        size_min = sizes[0] if sizes else 0
                        size_max = sizes[-1] if sizes else 0
                        size_avg = sum(sizes)/len(sizes) if sizes else 0
                        size_median = sizes[len(sizes)//2] if sizes else 0

                        advanced_html = '''
                        <div class="card">
                            <div class="section-title">Advanced Statistics (Last 1 Hour)</div>
                            
                            <div class="grid-stats">
                                <div class="stat-card">
                                    <div class="stat-label">Speed Stats (bps)</div>
                                    <div class="stat-sub">Min: SPEED_MIN</div>
                                    <div class="stat-sub">Max: SPEED_MAX</div>
                                    <div class="stat-sub">Avg: SPEED_AVG</div>
                                    <div class="stat-sub">Median: SPEED_MEDIAN</div>
                                </div>
                                <div class="stat-card">
                                    <div class="stat-label">File Size Stats (bytes)</div>
                                    <div class="stat-sub">Min: SIZE_MIN</div>
                                    <div class="stat-sub">Max: SIZE_MAX</div>
                                    <div class="stat-sub">Avg: SIZE_AVG</div>
                                    <div class="stat-sub">Median: SIZE_MEDIAN</div>
                                </div>
                            </div>
                            
                            <div style="margin-top: 20px;">
                                <canvas id="chartRequests"></canvas>
                            </div>
                            <div style="margin-top: 20px;">
                                <canvas id="chartCodes"></canvas>
                            </div>
                            <div style="margin-top: 20px;">
                                <canvas id="chartSpeed"></canvas>
                            </div>

                            <script>
                                const tData = TIMELINE_DATA;
                                const labels = tData.map(d => d.minute.split(" ")[1]);
                                
                                new Chart(document.getElementById('chartRequests'), {
                                    type: 'line',
                                    data: {
                                        labels: labels,
                                        datasets: [{
                                            label: 'Requests/min',
                                            data: tData.map(d => d.requests),
                                            borderColor: '#3b82f6',
                                            tension: 0.1
                                        }]
                                    },
                                    options: { responsive: true, plugins: { title: { display: true, text: 'Requests per Minute', color: '#fff' } } }
                                });

                                new Chart(document.getElementById('chartCodes'), {
                                    type: 'line',
                                    data: {
                                        labels: labels,
                                        datasets: [
                                            { label: '200 OK', data: tData.map(d => d.rc_200), borderColor: '#10b981', backgroundColor: 'rgba(16, 185, 129, 0.2)', fill: true },
                                            { label: '429 Throttled', data: tData.map(d => d.rc_429), borderColor: '#f59e0b', backgroundColor: 'rgba(245, 158, 11, 0.2)', fill: true },
                                            { label: '500 Error', data: tData.map(d => d.rc_500), borderColor: '#ef4444', backgroundColor: 'rgba(239, 68, 68, 0.2)', fill: true },
                                            { label: 'Other', data: tData.map(d => d.rc_other), borderColor: '#9ca3af', backgroundColor: 'rgba(156, 163, 175, 0.2)', fill: true }
                                        ]
                                    },
                                    options: { responsive: true, scales: { x: { stacked: true }, y: { stacked: true } }, plugins: { title: { display: true, text: 'Return Codes (Stacked)', color: '#fff' } } }
                                });

                                new Chart(document.getElementById('chartSpeed'), {
                                    type: 'line',
                                    data: {
                                        labels: labels,
                                        datasets: [{
                                            label: 'Sum Speed (bps)',
                                            data: tData.map(d => d.sum_speed_bps),
                                            borderColor: '#a78bfa',
                                            tension: 0.1
                                        }]
                                    },
                                    options: { responsive: true, plugins: { title: { display: true, text: 'Download Speed over last 1h (lagged 1m)', color: '#fff' } } }
                                });
                            </script>
                        </div>
                        ''' \
                        .replace('SPEED_MIN', f'{speed_min:.0f}') \
                        .replace('SPEED_MAX', f'{speed_max:.0f}') \
                        .replace('SPEED_AVG', f'{speed_avg:.0f}') \
                        .replace('SPEED_MEDIAN', f'{speed_median:.0f}') \
                        .replace('SIZE_MIN', f'{size_min}') \
                        .replace('SIZE_MAX', f'{size_max}') \
                        .replace('SIZE_AVG', f'{size_avg:.0f}') \
                        .replace('SIZE_MEDIAN', f'{size_median}') \
                        .replace('TIMELINE_DATA', json.dumps(timeline_data))
                        view_content = advanced_html

                    elif view == 'explorer':

                        search_q = params.get("q", [""])[0].strip()
                        if search_q:
                            c.execute("SELECT id, url, is_dir, is_vip, status, file_size FROM tasks WHERE url LIKE ? ORDER BY url ASC LIMIT 5000", (f"%{search_q}%",))
                        else:
                            c.execute("SELECT id, url, is_dir, is_vip, status, file_size FROM tasks ORDER BY url ASC LIMIT 10000")
                        
                        tasks = [dict(r) for r in c.fetchall()]

                        tree_root = build_tree_structure(tasks)
                        tree_html = render_tree_node(tree_root)

                        explorer_html = f"""
                        <div class="card">
                            <div class="section-title">
                                Collapsible Directory Explorer
                                <span style="font-size: 12px; font-weight: normal; color: var(--text-muted);">Folder badges rollup to the lowest status of all sub-files. Unfold folders to view relative sub-files.</span>
                            </div>
                            <form method="GET" action="/ui" class="search-box">
                                <input type="hidden" name="view" value="explorer" />
                                <div style="display: flex; gap: 10px;">
                                    <input type="text" name="q" value="{search_q}" placeholder="Search cataloged files or folders..." />
                                    <button type="submit" class="btn-submit">Search</button>
                                </div>
                            </form>
                            <div class="tree-container">
                                {tree_html if tree_html else '<div class="empty-folder">No cataloged items found in queue.</div>'}
                            </div>
                        </div>
                        """
                        view_content = explorer_html

                    elif view == 'mobile':
                        import datetime
                        c.execute("SELECT count(*) as count FROM stats_log WHERE return_code = 429 AND datetime(timestamp) >= datetime('now', '-5 minutes')")
                        recent_429_count = c.fetchone()['count']
                        c.execute("SELECT count(*) as count FROM stats_log WHERE datetime(timestamp) >= datetime('now', '-5 minutes')")
                        total_5m_count = c.fetchone()['count']
                        perc_429 = (recent_429_count / total_5m_count * 100) if total_5m_count > 0 else 0

                        c.execute("SELECT sum(speed_bps) as sum_speed, count(*) as cnt FROM stats_log WHERE return_code = 200 AND datetime(timestamp) >= datetime('now', '-5 minutes')")
                        speed_5m_row = c.fetchone()
                        speed_5m_avg = (speed_5m_row['sum_speed'] / speed_5m_row['cnt']) if (speed_5m_row and speed_5m_row['cnt'] > 0) else 0
                        speed_5m_str = human_size(speed_5m_avg) + "/s" if speed_5m_avg > 0 else "0 B/s"

                        total_est_bytes = comp_bytes + est_rem_bytes
                        completion_pct = (comp_bytes / total_est_bytes * 100) if total_est_bytes > 0 else 0

                        paused = is_paused()
                        pause_btn = '<a href="/ui/toggle_pause" class="btn btn-resume" style="flex:1;text-align:center;justify-content:center;padding:12px;">Resume</a>' if paused else '<a href="/ui/toggle_pause" class="btn btn-pause" style="flex:1;text-align:center;justify-content:center;padding:12px;">Pause</a>'
                        retry_btn = '<a href="/ui/retry_failed" class="btn btn-retry" style="flex:1;text-align:center;justify-content:center;padding:12px;">Retry Failed</a>'

                        warning_html = ""
                        if perc_429 > 10:
                            warning_html = f'<div style="background: rgba(239, 68, 68, 0.2); color: var(--danger); padding: 12px; margin-bottom: 20px; border-radius: 6px; border: 1px solid var(--danger); font-weight: bold; text-align: center;">⚠️ Server Throttling! High 429s ({perc_429:.1f}%)</div>'

                        eta_html = "N/A"
                        if speed_bps > 0 and est_rem_bytes > 0:
                            seconds_left = int(est_rem_bytes / speed_bps)
                            eta_dt = datetime.datetime.now() + datetime.timedelta(seconds=seconds_left)
                            eta_html = eta_dt.strftime("%Y-%m-%d %H:%M:%S")

                        mobile_html = f"""
                        <style>.grid-stats {{ display: none !important; }} header .actions {{ display: none !important; }}</style>
                        <div style="max-width: 600px; margin: 0 auto; margin-top: 20px;">
                            {warning_html}
                            <div class="card" style="padding: 24px; text-align: center; margin-bottom: 20px;">
                                <div style="font-size: 14px; color: var(--text-muted); text-transform: uppercase; font-weight: 600; letter-spacing: 0.05em; margin-bottom: 8px;">Completion</div>
                                <div style="font-size: 42px; font-weight: bold; color: #4ade80; margin-bottom: 8px;">{completion_pct:.1f}%</div>
                                <div style="font-size: 14px; color: var(--text-muted); margin-bottom: 24px;">ETC: <strong style="color: #a78bfa;">{etc_str}</strong> (ETA: {eta_html})</div>
                                
                                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; text-align: left; background: rgba(0,0,0,0.2); padding: 16px; border-radius: 8px; margin-bottom: 24px;">
                                    <div>
                                        <div style="font-size: 11px; color: var(--text-muted); text-transform: uppercase;">Downloaded</div>
                                        <div style="font-size: 16px; font-weight: 600; color: #fff;">{comp_size_str}</div>
                                    </div>
                                    <div>
                                        <div style="font-size: 11px; color: var(--text-muted); text-transform: uppercase;">Remaining</div>
                                        <div style="font-size: 16px; font-weight: 600; color: #f472b6;">{human_size(est_rem_bytes)}</div>
                                    </div>
                                    <div>
                                        <div style="font-size: 11px; color: var(--text-muted); text-transform: uppercase;">Speed (5m)</div>
                                        <div style="font-size: 16px; font-weight: 600; color: #38bdf8;">{speed_5m_str}</div>
                                    </div>
                                    <div>
                                        <div style="font-size: 11px; color: var(--text-muted); text-transform: uppercase;">429 Errors</div>
                                        <div style="font-size: 16px; font-weight: 600; color: {'var(--danger)' if perc_429 > 10 else 'var(--warning)'};">{perc_429:.1f}%</div>
                                    </div>
                                </div>
                                
                                <div style="display: flex; gap: 12px; margin-top: 24px;">
                                    {pause_btn}
                                    {retry_btn}
                                </div>
                            </div>
                        </div>
                        """
                        view_content = mobile_html

                    else:
                        c.execute('SELECT * FROM tasks WHERE status IN ("pending", "assigned") ORDER BY is_vip DESC, vip_added_at ASC, id ASC LIMIT 100')
                        active_queue = [dict(r) for r in c.fetchall()]

                        queue_rows = ""
                    
                    c.execute("SELECT count(*) as count FROM stats_log WHERE return_code = 429 AND datetime(timestamp) >= datetime('now', '-5 minutes')")
                    recent_429s = c.fetchone()['count']
                    throttling_warning = ""
                    if recent_429s > 20:
                        throttling_warning = f'<div style="background: rgba(239, 68, 68, 0.2); color: var(--danger); padding: 10px; margin-bottom: 20px; border-radius: 6px; border: 1px solid var(--danger);"><strong>Warning:</strong> High number of 429 Too Many Requests errors detected ({recent_429s} in last 5m). Throttling may be occurring.</div>'
                        
                finally:
                    conn.close()

                
                    if view not in ('explorer', 'advanced', 'mobile'):
                        for t in active_queue:
                            rel = extract_relative_path(t['url'])
                            badge = "VIP Pending" if (t['is_vip'] and t['status'] == 'pending') else t['status']
                            badge_cls = "badge-vip" if (t['is_vip'] and t['status'] == 'pending') else f"badge-{t['status']}"
                            worker_str = t['worker_id'] or "-"
                            size_str = human_size(t['file_size']) if t['file_size'] else "-"

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

                total_est_bytes = comp_bytes + est_rem_bytes
                completion_pct = (comp_bytes / total_est_bytes * 100) if total_est_bytes > 0 else 0
                rem_size_str = human_size(est_rem_bytes)

                html = HTML_TEMPLATE
                html = html.replace("STATUS_BADGE", status_badge)
                html = html.replace("RETRY_FAILED_BTN", retry_failed_btn)
                html = html.replace("PAUSE_RESUME_BTN", pause_btn)
                html = html.replace("DOWNLOAD_SPEED", speed_str)
                html = html.replace("ETC_TIME", etc_str)
                html = html.replace("VIP_TASKS", f"{vip_count:,}")
                html = html.replace("PENDING_TASKS", f"{stats.get('pending', 0):,}")
                html = html.replace("COMPLETED_SIZE", comp_size_str)
                html = html.replace("COMPLETED_COUNT", f"{completed_info['total'] or 0:,}")
                html = html.replace("REMAINING_SIZE", rem_size_str)
                html = html.replace("COMPLETION_PERCENT", f"{completion_pct:.2f}")
                html = html.replace("ACTIVE_WORKERS", str(len(workers)))
                html = html.replace("TAB_QUEUE_ACTIVE", "active" if view == "queue" else "")
                html = html.replace("TAB_EXPLORER_ACTIVE", "active" if view == "explorer" else "")
                html = html.replace("TAB_ADVANCED_ACTIVE", "active" if view == "advanced" else "")
                html = html.replace("THROTTLING_WARNING", throttling_warning)
                html = html.replace("VIEW_CONTENT", view_content)

                self._send_html(html)

            elif parsed.path == '/api/status':
                conn = get_db()
                try:
                    c = conn.cursor()
                    c.execute('SELECT status, count(*) as count FROM tasks GROUP BY status')
                    stats = {row['status']: row['count'] for row in c.fetchall()}
                    c.execute('SELECT count(*) as total, sum(file_size) as total_bytes FROM tasks WHERE status="completed"')
                    completed_info = c.fetchone()
                    workers = get_active_workers(300)
                    speed_str, etc_str, speed_bps, est_rem_bytes = calculate_speed_and_etc(conn)
                finally:
                    conn.close()
                
                self._send_json({
                    "paused": is_paused(),
                    "stats": stats,
                    "download_speed": speed_str,
                    "speed_bps": speed_bps,
                    "etc": etc_str,
                    "est_remaining_bytes": est_rem_bytes,
                    "completed_count": completed_info['total'] or 0,
                    "completed_bytes": completed_info['total_bytes'] or 0,
                    "active_workers": workers
                })
            elif parsed.path == '/api/staging_tasks':
                conn = get_db()
                try:
                    c = conn.cursor()
                    c.execute('SELECT * FROM tasks WHERE status = "downloaded_staging" LIMIT 200')
                    tasks = [dict(r) for r in c.fetchall()]
                finally:
                    conn.close()
                self._send_json({"tasks": tasks})
            elif parsed.path == '/api/tasks':
                conn = get_db()
                try:
                    c = conn.cursor()
                    c.execute('SELECT * FROM tasks ORDER BY id DESC LIMIT 100')
                    tasks = [dict(r) for r in c.fetchall()]
                finally:
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
                    with DB_WRITE_LOCK:
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
                with DB_WRITE_LOCK:
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

            elif parsed.path == '/api/reset_queue':
                with DB_WRITE_LOCK:
                    conn = get_db()
                    c = conn.cursor()
                    c.execute("DELETE FROM tasks")
                    c.execute("DELETE FROM workers")
                    c.execute("VACUUM")
                    conn.commit()
                    conn.close()
                self._send_json({"status": "ok", "message": "Queue database completely reset"})

            elif parsed.path == '/api/claim':
                worker_id = body.get("worker_id", "unknown")
                update_worker_heartbeat(worker_id)

                if is_paused():
                    self._send_json({"task": None, "paused": True})
                    return

                with DB_WRITE_LOCK:
                    conn = get_db()
                    try:
                        c = conn.cursor()
                        c.execute('SELECT * FROM tasks WHERE status = "pending" ORDER BY is_vip DESC, id ASC LIMIT 1')
                        row = c.fetchone()
                        if row:
                            task = dict(row)
                            c.execute('''
                                UPDATE tasks
                                SET status = "assigned", worker_id = ?, attempts = attempts + 1, updated_at = CURRENT_TIMESTAMP
                                WHERE id = ?
                            ''', (worker_id, task['id']))
                            conn.commit()
                            self._send_json({"task": task})
                        else:
                            self._send_json({"task": None})
                    finally:
                        conn.close()

            elif parsed.path == '/api/report_staging':
                task_id = body.get("task_id")
                worker_id = body.get("worker_id", "unknown")
                staging_path = body.get("staging_path")
                file_size = body.get("file_size", 0)
                file_hash = body.get("file_hash", "")
                discovered_urls = body.get("discovered_urls", [])

                update_worker_heartbeat(worker_id, increment_task=True)

                with DB_WRITE_LOCK:
                    conn = get_db()
                    try:
                        c = conn.cursor()
                        if discovered_urls:
                            valid_items = [
                                (u.strip(), body.get("url"), 1 if u.strip().endswith('/') else 0)
                                for u in discovered_urls if u.strip()
                            ]
                            if valid_items:
                                c.executemany('INSERT OR IGNORE INTO tasks (url, parent_url, is_dir, status) VALUES (?, ?, ?, "pending")', valid_items)

                        # If directory crawl or no staging path, complete task directly
                        if discovered_urls or not staging_path:
                            c.execute('''
                                UPDATE tasks
                                SET status = "completed", staging_path = "", file_size = 0, file_hash = "", updated_at = CURRENT_TIMESTAMP
                                WHERE id = ?
                            ''', (task_id,))
                        else:
                            c.execute('''
                                UPDATE tasks
                                SET status = "downloaded_staging", staging_path = ?, file_size = ?, file_hash = ?, updated_at = CURRENT_TIMESTAMP
                                WHERE id = ?
                            ''', (staging_path, file_size, file_hash, task_id))
                        conn.commit()
                        self._send_json({"status": "ok"})
                    finally:
                        conn.close()

            elif parsed.path == '/api/report_completed':
                task_id = body.get("task_id")
                local_rel_path = body.get("local_rel_path")
                file_size = body.get("file_size", 0)
                file_hash = body.get("file_hash", "")
                worker_id = body.get("worker_id", "unknown")
                speed_bps = float(body.get("speed_bps", 0))
                update_worker_heartbeat(worker_id, increment_task=True)

                with DB_WRITE_LOCK:
                    conn = get_db()
                    try:
                        c = conn.cursor()
                        c.execute('''
                            INSERT INTO stats_log (return_code, speed_bps, file_size, worker_id)
                            VALUES (?, ?, ?, ?)
                        ''', (200, speed_bps, file_size, worker_id))
                        c.execute('''
                            UPDATE tasks
                            SET status = "completed", local_rel_path = ?, file_size = ?, file_hash = ?, updated_at = CURRENT_TIMESTAMP
                            WHERE id = ?
                        ''', (local_rel_path, file_size, file_hash, task_id))
                        conn.commit()
                        self._send_json({"status": "ok"})
                    finally:
                        conn.close()

            elif parsed.path == '/api/requeue':
                task_id = body.get("task_id")
                worker_id = body.get("worker_id", "unknown")
                with DB_WRITE_LOCK:
                    conn = get_db()
                    try:
                        c = conn.cursor()
                        if task_id:
                            c.execute("""
                                UPDATE tasks
                                SET status = 'pending', worker_id = NULL, error_message = NULL, updated_at = CURRENT_TIMESTAMP
                                WHERE id = ?
                            """, (task_id,))
                            c.execute('''
                                INSERT INTO stats_log (return_code, speed_bps, file_size, worker_id)
                                VALUES (?, ?, ?, ?)
                            ''', (429, 0, 0, worker_id))
                        conn.commit()
                        self._send_json({"status": "ok", "message": "Task requeued"})
                    finally:
                        conn.close()

            elif parsed.path == '/api/report_failed':
                task_id = body.get("task_id")
                error = str(body.get("error", "Unknown error"))
                with DB_WRITE_LOCK:
                    conn = get_db()
                    try:
                        c = conn.cursor()

                        # If 429 or rate limit, do NOT count as a failure or increment attempt penalty; requeue as pending
                        return_code = 500
                        if "429" in error or "Too Many Requests" in error or "rate limit" in error.lower():
                            return_code = 429
                            c.execute("""
                                UPDATE tasks
                                SET status = 'pending', worker_id = NULL, error_message = NULL, updated_at = CURRENT_TIMESTAMP
                                WHERE id = ?
                            """, (task_id,))
                            new_status = 'pending'
                        else:
                            c.execute('SELECT attempts FROM tasks WHERE id = ?', (task_id,))
                            row = c.fetchone()
                            attempts = row['attempts'] if row else 1
                            new_status = 'failed' if attempts >= 10 else 'pending'
                            c.execute('''
                                UPDATE tasks
                                SET status = ?, error_message = ?, worker_id = NULL, updated_at = CURRENT_TIMESTAMP
                                WHERE id = ?
                            ''', (new_status, error, task_id))

                        c.execute('''
                            INSERT INTO stats_log (return_code, speed_bps, file_size, worker_id)
                            VALUES (?, ?, ?, ?)
                        ''', (return_code, 0, 0, "unknown"))

                        conn.commit()
                        self._send_json({"status": "ok", "new_status": new_status})
                    finally:
                        conn.close()

            else:
                self._send_json({"error": "Not found"}, 404)
        except Exception as e:
            traceback.print_exc()
            self._send_json({"error": str(e)}, 500)

def start_maintenance_thread(interval=10):
    def _maintenance_loop():
        # Reset any leftover assigned tasks on server startup
        try:
            with DB_WRITE_LOCK:
                conn = get_db()
                conn.execute("UPDATE tasks SET status = 'pending', worker_id = NULL, updated_at = CURRENT_TIMESTAMP WHERE status = 'assigned'")
                conn.commit()
                conn.close()
            print("[Maintenance] Cleaned and reset startup assigned tasks.")
        except Exception as e:
            print(f"[Maintenance] Startup error: {e}")

        while True:
            time.sleep(interval)
            try:
                with DB_WRITE_LOCK:
                    conn = get_db()
                    c = conn.cursor()
                    # 1. Auto-reclaim stuck assigned tasks older than 60s
                    c.execute("""
                        UPDATE tasks
                        SET status = 'pending', worker_id = NULL, updated_at = CURRENT_TIMESTAMP
                        WHERE status = 'assigned' AND (julianday('now') - julianday(updated_at)) * 86400 > 60
                    """)
                    reclaimed = c.rowcount
                    if reclaimed > 0:
                        print(f"[Maintenance] Auto-reclaimed {reclaimed} expired assigned tasks.")

                    # 2. Checkpoint WAL log
                    c.execute("PRAGMA wal_checkpoint(PASSIVE);")

                    conn.commit()
                    conn.close()
            except Exception as e:
                pass

    t = threading.Thread(target=_maintenance_loop, daemon=True)
    t.start()

def run_server(port=8888):
    init_db()
    start_maintenance_thread(10)
    server_address = ('0.0.0.0', port)
    httpd = ThreadingHTTPServer(server_address, QueueHandler)
    print(f"Queue Coordinator & Management UI running on port {port} with DB {DB_PATH}")
    httpd.serve_forever()

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8888
    run_server(port)
