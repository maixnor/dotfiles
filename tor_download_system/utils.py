import urllib.parse
import time
import threading

WORKERS_LOCK = threading.Lock()
WORKERS_MAP = {}

METRICS_CACHE = {"timestamp": 0, "result": ("Idle", "Calculating...", 0.0, 0.0)}
METRICS_LOCK = threading.Lock()

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
