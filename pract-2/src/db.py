import sqlite3

DB_FILE = "mail.db"

def init_db():
    with sqlite3.connect(DB_FILE) as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS users (
                username TEXT PRIMARY KEY,
                token TEXT UNIQUE NOT NULL
            )
        """)

        conn.execute("""
            CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                recipient TEXT NOT NULL,
                sender TEXT NOT NULL,
                subject TEXT NOT NULL,
                body TEXT NOT NULL
            )
        """)

def get_connection():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row  # Access columns by name: row["subject"]
    return conn

def create_user(username: str, token: str) -> bool:
    try:
        with get_connection() as conn:
            conn.execute(
                "INSERT INTO users (username, token) VALUES (?, ?)", 
                (username, token)
            )
            return True
    except sqlite3.IntegrityError:
        return False

def get_user_by_token(token: str) -> str | None:
    """Returns username if token matches, otherwise None."""
    with get_connection() as conn:
        row = conn.execute("SELECT username FROM users WHERE token = ?", (token,)).fetchone()
        return row["username"] if row else None

def insert_messages_bulk(recipients: list[str], sender: str, subject: str, body: str) -> None:
    records = [(rcpt, sender, subject, body) for rcpt in recipients]
    with get_connection() as conn:
        conn.executemany(
            "INSERT INTO messages (recipient, sender, subject, body) VALUES (?, ?, ?, ?)",
            records
        )

def get_message_summaries(user: str, limit: int = 50) -> list[dict]:
    with get_connection() as conn:
        cursor = conn.execute(
            """
            SELECT id, sender, subject 
            FROM messages 
            WHERE recipient = ? 
            ORDER BY id DESC 
            LIMIT ?
            """, 
            (user, limit)
        )
        return [dict(row) for row in cursor.fetchall()]

def get_message_by_id(message_id: int, user: str) -> dict | None:
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT id, recipient, sender, subject, body 
            FROM messages 
            WHERE id = ? AND recipient = ?
            """, 
            (message_id, user)
        ).fetchone()
        return dict(row) if row else None