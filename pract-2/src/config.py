import os
from pathlib import Path

env_path = Path(".env")
if env_path.is_file():
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            os.environ.setdefault(k.strip(), v.strip().strip("'\""))

HOST = os.getenv("MAIL_HOST", "127.0.0.1")
PORT = int(os.getenv("MAIL_PORT", "8000"))
SERVER_URL = f"http://{HOST}:{PORT}"