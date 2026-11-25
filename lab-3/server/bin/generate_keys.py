from pathlib import Path
import sys

SERVER_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVER_ROOT / "src"))

from lab3_server.keys import generate_key_pair


if __name__ == "__main__":
    private_key_path = SERVER_ROOT / "private_key.pem"
    public_key_path = SERVER_ROOT / "public_key.pem"
    _, public_key_pem = generate_key_pair(private_key_path, public_key_path)
    print(public_key_pem.decode("ascii"))
