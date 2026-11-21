import argparse
import base64
import json
import os
import secrets
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

import config


def generate_otp_key(length: int) -> str:
    raw_key = secrets.token_bytes(length)
    return base64.b64encode(raw_key).decode("ascii")


def encrypt_body(body: str, key_b64: str) -> str:
    body_bytes = body.encode("utf-8")
    key_bytes = base64.b64decode(key_b64.encode("ascii"))
    if len(key_bytes) < len(body_bytes):
        sys.exit("Error: Key is shorter than the message.")
    cipher_bytes = bytes(b ^ k for b, k in zip(body_bytes, key_bytes))
    return base64.b64encode(cipher_bytes).decode("ascii")


def decrypt_body(ciphertext_b64: str, key_b64: str) -> str:
    try:
        cipher_bytes = base64.b64decode(ciphertext_b64.encode("ascii"))
        key_bytes = base64.b64decode(key_b64.encode("ascii"))
        plain_bytes = bytes(c ^ k for c, k in zip(cipher_bytes, key_bytes))
        return plain_bytes.decode("utf-8")
    except Exception as e:
        sys.exit(f"Error: Decryption failed ({e}).")


# ==========================================
# AUTH & HTTP HELPERS
# ==========================================


def load_token(args: argparse.Namespace) -> str:
    """Gets token from --token CLI flag, --env-file, or environment."""
    token = args.token

    if args.env_file:
        env_path = Path(args.env_file)
        if not env_path.is_file():
            sys.exit(f"Error: Env file not found: {args.env_file}")
        for line in env_path.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                if k.strip().upper() == "MAIL_TOKEN" and not token:
                    token = v.strip().strip("'\"")

    if not token:
        token = os.getenv("MAIL_TOKEN")

    if not token:
        sys.exit(
            "Error: Authentication token required (pass --token, set MAIL_TOKEN in .env, or export MAIL_TOKEN)."
        )

    return token


def make_request(
    url: str, method: str = "GET", data: dict = None, token: str = None
) -> dict:
    req_data = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(url, data=req_data, method=method)
    req.add_header("Content-Type", "application/json")

    if token:
        req.add_header("Authorization", f"Bearer {token}")

    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err_msg = e.read().decode("utf-8", errors="ignore")
        try:
            detail = json.loads(err_msg).get("detail", err_msg)
        except Exception:
            detail = err_msg
        sys.exit(f"HTTP Error {e.code}: {detail}")
    except urllib.error.URLError as e:
        sys.exit(f"Connection failed: {e.reason}")


# ==========================================
# COMMAND IMPLEMENTATIONS
# ==========================================


def parse_editor_buffer(content: str) -> tuple[list[str], str, str]:
    lines = content.splitlines()
    if len(lines) < 3:
        sys.exit("Error: Buffer corrupted. Expected headers and separator '---'.")

    if not lines[0].startswith("To:"):
        sys.exit("Error: Format violation. Line 1 must start with 'To: <recipients>'")
    raw_to = lines[0][len("To:") :].strip()
    recipients = [r.strip() for r in raw_to.split(",") if r.strip()]

    if not lines[1].startswith("Subject:"):
        sys.exit("Error: Format violation. Line 2 must start with 'Subject: <topic>'")
    subject = lines[1][len("Subject:") :].strip()

    if lines[2].strip() != "---":
        sys.exit("Error: Format violation. Line 3 must be exactly '---' delimiter.")

    body = "\n".join(lines[3:]).strip()
    if not recipients:
        sys.exit("Error: At least one recipient required.")
    if not subject:
        sys.exit("Error: Subject cannot be empty.")

    return recipients, subject, body


def cmd_send(args: argparse.Namespace):
    token = load_token(args)

    if args.editor:
        template = "To: \nSubject: \n---\n\n"
        editor = os.environ.get("EDITOR", "notepad" if os.name == "nt" else "nano")

        with tempfile.NamedTemporaryFile(suffix=".tmp", mode="w+", delete=False) as tf:
            tf.write(template)
            tf.flush()
            temp_path = tf.name

        try:
            status = subprocess.call([editor, temp_path])
            if status != 0:
                sys.exit(f"Error: Editor exited with code {status}")
            content = Path(temp_path).read_text()
        finally:
            if os.path.exists(temp_path):
                os.remove(temp_path)

        recipients, subject, body = parse_editor_buffer(content)
    else:
        if not args.to or not args.subject or not args.file:
            sys.exit(
                "Error: Sending without --editor requires --to, --subject, and --file."
            )
        file_path = Path(args.file)
        if not file_path.is_file():
            sys.exit(f"Error: File not found: {args.file}")

        recipients = [r.strip() for r in args.to.split(",") if r.strip()]
        subject = args.subject
        body = file_path.read_text()

    if args.encrypt:
        key_path = Path(args.gen_key_path) if args.gen_key_path else Path("secret.key")

        byte_length = len(body.encode("utf-8"))
        otp_key = generate_otp_key(byte_length)

        key_path.write_text(otp_key, encoding="utf-8")
        print(f"[+] Message encrypted. Key saved to: {key_path.resolve()}")

        body = encrypt_body(body, otp_key)

    payload = {"recipients": recipients, "subject": subject, "body": body}
    make_request(
        f"{config.SERVER_URL}/messages", method="POST", data=payload, token=token
    )
    print(f"Success: Message sent to {', '.join(recipients)}.")


def cmd_inbox(args: argparse.Namespace):
    token = load_token(args)
    data = make_request(
        f"{config.SERVER_URL}/messages?limit={args.limit}", method="GET", token=token
    )

    inbox = data.get("inbox", [])
    if not inbox:
        print("Inbox is empty.")
        return

    print(f"{'ID':<6} | {'FROM':<20} | {'SUBJECT'}")
    print("-" * 60)
    for msg in inbox:
        print(f"{msg['id']:<6} | {msg['sender']:<20} | {msg['subject']}")


def cmd_read(args: argparse.Namespace):
    token = load_token(args)
    msg = make_request(
        f"{config.SERVER_URL}/messages/{args.id}", method="GET", token=token
    )

    body = msg["body"]

    # Decrypt if a key file was provided
    if args.key_file:
        key_path = Path(args.key_file)
        if not key_path.is_file():
            sys.exit(f"Error: Key file not found: {args.key_file}")

        key = key_path.read_text(encoding="utf-8").strip()
        body = decrypt_body(body, key)

    print("=" * 60)
    print(f"ID:      {msg['id']}")
    print(f"From:    {msg['sender']}")
    print(f"To:      {msg['recipient']}")
    print(f"Subject: {msg['subject']}")
    print("=" * 60)
    print(body)
    print("=" * 60)


# ==========================================
# CLI PARSER
# ==========================================


def main():
    parser = argparse.ArgumentParser(description="Non-interactive Mail CLI Client")
    parser.add_argument("--token", help="User API Bearer Token")
    parser.add_argument("--env-file", help="Path to .env file containing MAIL_TOKEN")

    subparsers = parser.add_subparsers(dest="command", required=True)

    # Send subparser
    send_p = subparsers.add_parser("send", help="Send a letter")
    send_p.add_argument("--to", help="Comma-separated recipients")
    send_p.add_argument("--subject", help="Subject of the letter")
    send_p.add_argument("--file", help="Path to file containing body")
    send_p.add_argument("--editor", action="store_true", help="Compose in $EDITOR")
    # Encryption arguments:
    send_p.add_argument(
        "--encrypt", action="store_true", help="Encrypt letter body with OTP"
    )
    send_p.add_argument(
        "--gen-key-path", help="Path to save generated OTP key (default: secret.key)"
    )

    # Read subparser
    read_p = subparsers.add_parser("read", help="Read full letter content by ID")
    read_p.add_argument("--id", type=int, required=True, help="Letter ID")
    # Decryption argument:
    read_p.add_argument("--key-file", help="Path to OTP key file for decryption")

    # Inbox
    inbox_p = subparsers.add_parser(
        "inbox", help="View inbox summaries (newest to oldest)"
    )
    inbox_p.add_argument(
        "--limit", type=int, required=True, help="Number of letters to list"
    )

    args = parser.parse_args()

    commands = {
        "send": cmd_send,
        "inbox": cmd_inbox,
        "read": cmd_read,
    }
    commands[args.command](args)


if __name__ == "__main__":
    main()
