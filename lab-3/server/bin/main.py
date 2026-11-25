from pathlib import Path
import sys

SERVER_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVER_ROOT / "src"))

from lab3_server.app import app

__all__ = ["app"]
