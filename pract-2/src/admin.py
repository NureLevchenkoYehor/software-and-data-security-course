import secrets
import sys

import db

db.init_db()


def main():
    if len(sys.argv) < 3 or sys.argv[1] != "add-user":
        sys.exit("Usage: python admin.py add-user <username>")

    username = sys.argv[2].strip()
    if not username:
        sys.exit("Error: Username cannot be empty.")

    raw_token = f"mail_{secrets.token_hex(24)}"

    success = db.create_user(username, raw_token)
    if not success:
        sys.exit(f"Error: User '{username}' already exists.")

    print("=" * 60)
    print(f"User '{username}' created successfully.")
    print(f"API Token: {raw_token}")
    print("=" * 60)
    print("Give this token to the user. They must put it in their .env file as:")
    print(f"MAIL_TOKEN={raw_token}")


if __name__ == "__main__":
    main()
