import sqlite3
import os
import threading

DB_PATH = os.environ.get("QUEUE_DB_PATH", "/var/lib/tor-downloader/queue.db")
DB_WRITE_LOCK = threading.Lock()

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
