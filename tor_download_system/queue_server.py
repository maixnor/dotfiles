#!/usr/bin/env python3
import json
import time
import os
import sys
import threading
import traceback
import urllib.parse
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

from db import init_db, get_db, DB_PATH, DB_WRITE_LOCK
from utils import (
    update_worker_heartbeat, get_active_workers, extract_relative_path,
    build_tree_structure, compute_node_rollup_status, human_size,
    render_tree_node, calculate_speed_and_etc
)

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


def get_queue_metrics(conn, is_vip):
    c = conn.cursor()
    vip_val = 1 if is_vip else 0
    c.execute("SELECT COUNT(*) as cnt FROM tasks WHERE is_vip = ? AND status = 'assigned'", (vip_val,))
    active_streams = c.fetchone()['cnt']
    
    c.execute("SELECT COUNT(*) as cnt FROM tasks WHERE is_vip = ? AND status = 'pending'", (vip_val,))
    pending_tasks = c.fetchone()['cnt']

    c.execute("SELECT COUNT(*) as cnt FROM tasks WHERE is_vip = ? AND status = 'completed'", (vip_val,))
    completed_tasks = c.fetchone()['cnt']
    
    total = completed_tasks + pending_tasks + active_streams
    if total > 0:
        completion_pct = (completed_tasks / total) * 100.0
    else:
        completion_pct = 0.0

    c.execute("""
        SELECT SUM(file_size) as recent_bytes, COUNT(*) as recent_tasks
        FROM tasks 
        WHERE status IN ('downloaded_staging', 'completed') 
          AND is_vip = ?
          AND datetime(updated_at) >= datetime('now', '-10 minutes')
    """, (vip_val,))
    rec_row = c.fetchone()
    recent_bytes = rec_row['recent_bytes'] or 0
    recent_tasks = rec_row['recent_tasks'] or 0

    speed_bps = recent_bytes / 600.0
    tasks_per_sec = recent_tasks / 600.0

    c.execute("""
        SELECT SUM(file_size) as known_bytes, COUNT(*) as total_pending
        FROM tasks 
        WHERE status IN ('pending', 'assigned') AND is_dir = 0 AND is_vip = ?
    """, (vip_val,))
    p_info = c.fetchone()
    known_remaining = p_info['known_bytes'] or 0
    total_pending = p_info['total_pending'] or 0

    c.execute("""
        SELECT AVG(file_size) as avg_bytes
        FROM tasks
        WHERE status = 'completed' AND is_dir = 0 AND file_size > 0 AND is_vip = ?
    """, (vip_val,))
    avg_row = c.fetchone()
    avg_size = avg_row['avg_bytes'] if (avg_row and avg_row['avg_bytes']) else 500000

    c.execute("""
        SELECT COUNT(*) as unk_count
        FROM tasks
        WHERE status IN ('pending', 'assigned') AND is_dir = 0 AND (file_size IS NULL OR file_size = 0) AND is_vip = ?
    """, (vip_val,))
    unk_count = c.fetchone()['unk_count'] or 0

    est_remaining_bytes = known_remaining + (unk_count * avg_size)
    
    if total_pending == 0:
        etc_str = "Completed"
    elif speed_bps >= 1024:
        seconds_left = int(est_remaining_bytes / speed_bps)
        if seconds_left < 60: etc_str = f"{seconds_left}s"
        elif seconds_left < 3600: etc_str = f"{seconds_left // 60}m {seconds_left % 60}s"
        elif seconds_left < 86400: etc_str = f"{seconds_left // 3600}h {(seconds_left % 3600) // 60}m"
        else: etc_str = f"{seconds_left // 86400}d {(seconds_left % 86400) // 3600}h"
    elif tasks_per_sec > 0:
        seconds_left = int(total_pending / tasks_per_sec)
        if seconds_left < 60: etc_str = f"{seconds_left}s"
        elif seconds_left < 3600: etc_str = f"{seconds_left // 60}m {seconds_left % 60}s"
        elif seconds_left < 86400: etc_str = f"{seconds_left // 3600}h {(seconds_left % 3600) // 60}m"
        else: etc_str = f"{seconds_left // 86400}d {(seconds_left % 86400) // 3600}h"
    else:
        etc_str = "Calculating..."

    return {
        "pending": pending_tasks,
        "active": active_streams,
        "completion_pct": completion_pct,
        "etc": etc_str
    }

def load_template(name):
    path = os.path.join(os.path.dirname(__file__), 'templates', name)
    with open(path, 'r') as f:
        return f.read()

HTML_TEMPLATE = load_template('base.html')

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
            
            if parsed.path in ('/favicon.ico', '/logo.svg'):
                svg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <circle cx="50" cy="50" r="45" fill="#7D4698" />
  <circle cx="50" cy="50" r="30" fill="#5F2E76" />
  <circle cx="50" cy="50" r="15" fill="#4B205F" />
  <path d="M50 25 L50 70 M35 55 L50 70 L65 55" stroke="#FFFFFF" stroke-width="8" stroke-linecap="round" stroke-linejoin="round" fill="none" />
</svg>'''
                self.send_response(200)
                self.send_header('Content-Type', 'image/svg+xml')
                self.send_header('Cache-Control', 'public, max-age=31536000')
                self.end_headers()
                self.wfile.write(svg.encode('utf-8'))
                return

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

                        advanced_html = load_template('advanced.html') \
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

                        explorer_html = load_template('explorer.html').replace('{search_q}', search_q).replace('{tree_html if tree_html else \'<div class="empty-folder">No cataloged items found in queue.</div>\'}', tree_html if tree_html else '<div class="empty-folder">No cataloged items found in queue.</div>')
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

                        mobile_html = load_template('mobile.html').replace('{warning_html}', warning_html).replace('{completion_pct:.1f}', f'{completion_pct:.1f}').replace('{etc_str}', etc_str).replace('{eta_html}', eta_html).replace('{comp_size_str}', comp_size_str).replace('{human_size(est_rem_bytes)}', human_size(est_rem_bytes)).replace('{speed_5m_str}', speed_5m_str).replace('{perc_429:.1f}', f'{perc_429:.1f}').replace("{'var(--danger)' if perc_429 > 10 else 'var(--warning)'}", 'var(--danger)' if perc_429 > 10 else 'var(--warning)').replace('{pause_btn}', pause_btn).replace('{retry_btn}', retry_btn)
                        view_content = mobile_html

                    else:
                        c.execute('SELECT * FROM tasks WHERE status IN ("pending", "assigned") AND is_dir = 1 ORDER BY is_vip DESC, vip_added_at ASC, id ASC LIMIT 100')
                        active_queue = [dict(r) for r in c.fetchall()]

                        queue_rows = ""
                    
                    c.execute("SELECT count(*) as count FROM stats_log WHERE return_code = 429 AND datetime(timestamp) >= datetime('now', '-5 minutes')")
                    recent_429s = c.fetchone()['count']
                    throttling_warning = ""
                    if recent_429s > 20:
                        throttling_warning = f'<div style="background: rgba(239, 68, 68, 0.2); color: var(--danger); padding: 10px; margin-bottom: 20px; border-radius: 6px; border: 1px solid var(--danger);"><strong>Warning:</strong> High number of 429 Too Many Requests errors detected ({recent_429s} in last 5m). Throttling may be occurring.</div>'
                        
                    std_m = get_queue_metrics(conn, False)
                    vip_m = get_queue_metrics(conn, True)

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

                        queue_html = load_template('dashboard.html').replace("{queue_rows if queue_rows else '<tr><td colspan=\"6\" style=\"text-align: center; color: var(--text-muted);\">No active pending or VIP tasks in queue.</td></tr>'}", queue_rows if queue_rows else '<tr><td colspan="6" style="text-align: center; color: var(--text-muted);">No active pending or VIP tasks in queue.</td></tr>')
                        view_content = queue_html

                paused = is_paused()
                status_badge = '<span class="badge badge-failed" style="margin-left: 8px;">PAUSED</span>' if paused else '<span class="badge badge-completed" style="margin-left: 8px;">ACTIVE</span>'
                pause_btn = '<a href="/ui/toggle_pause" class="btn btn-resume">Resume Queue</a>' if paused else '<a href="/ui/toggle_pause" class="btn btn-pause">Pause Queue</a>'

                total_est_bytes = comp_bytes + est_rem_bytes
                completion_pct = (comp_bytes / total_est_bytes * 100) if total_est_bytes > 0 else 0
                rem_size_str = human_size(est_rem_bytes)


                html = HTML_TEMPLATE
                html = html.replace("STD_PENDING", str(std_m['pending']))
                html = html.replace("STD_ACTIVE", str(std_m['active']))
                html = html.replace("STD_COMPLETION%", f"{std_m['completion_pct']:.2f}%")
                html = html.replace("STD_ETC", std_m['etc'])
                
                if vip_m['pending'] > 0 or vip_m['active'] > 0:
                    vip_row = f"<tr><td><span style='color: var(--vip-gold);'>VIP</span></td><td>{vip_m['pending']}</td><td>{vip_m['active']}</td><td>{vip_m['completion_pct']:.2f}%</td><td>{vip_m['etc']}</td></tr>"
                    html = html.replace("VIP_ROW", vip_row)
                else:
                    html = html.replace("VIP_ROW", "")

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
                            c.execute('SELECT is_vip, vip_added_at FROM tasks WHERE id = ?', (task_id,))
                            parent_row = c.fetchone()
                            parent_is_vip = parent_row['is_vip'] if parent_row else 0
                            parent_vip_time = parent_row['vip_added_at'] if parent_row else None

                            valid_items = [
                                (u.strip(), body.get("url"), 1 if u.strip().endswith('/') else 0, parent_is_vip, parent_vip_time)
                                for u in discovered_urls if u.strip()
                            ]
                            if valid_items:
                                c.executemany('INSERT OR IGNORE INTO tasks (url, parent_url, is_dir, is_vip, vip_added_at, status) VALUES (?, ?, ?, ?, ?, "pending")', valid_items)

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
