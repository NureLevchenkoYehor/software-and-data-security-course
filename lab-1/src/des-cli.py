import argparse
from typing import NamedTuple

from des import bytes_to_list_int64, decrypt, encrypt, list_int64_to_bytes
from entropy import calculate_block_entropy


class RoundRecord(NamedTuple):
    round_idx: int
    left: int
    right: int
    entropy: float


def print_round_table(records: list[RoundRecord]):
    print(
        f"{'Round':^5} | {'Left (32-bit)':^13} | {'Right (32-bit)':^14} | {'Entropy':^6}"
    )
    print("-" * 62)

    for r in records:
        print(
            f"{r.round_idx:^5} | "
            f"{f'0x{r.left:08X}':^13} | "
            f"{f'0x{r.right:08X}':^14} | "
            f"{r.entropy:^6.4f}"
        )


def parse_hex_key(key_str: str) -> int:
    clean_hex = key_str.removeprefix("0x").removeprefix("0X")

    if len(clean_hex) != 16:
        raise argparse.ArgumentTypeError(
            f"DES key must be exactly 64-bit (16 hex characters), got {len(clean_hex)} ('{key_str}')."
        )

    try:
        return int(clean_hex, 16)
    except ValueError:
        raise argparse.ArgumentTypeError(f"Invalid hex string: '{key_str}'")


def parse_ciphertext_bytes(cipher_str: str) -> bytes:
    clean_hex = cipher_str.removeprefix("0x").removeprefix("0X")

    if len(clean_hex) % 16 != 0:
        raise argparse.ArgumentTypeError(
            "Ciphertext length must be a multiple of 16 hex characters (8 bytes per DES block)."
        )

    try:
        return bytes.fromhex(clean_hex)
    except ValueError:
        raise argparse.ArgumentTypeError(f"Invalid hex ciphertext: '{cipher_str}'")


def cmd_encrypt(args: argparse.Namespace):
    records: list[RoundRecord] = []

    def collect_record(round_idx: int, left: int, right: int) -> None:
        block_64bit = (right << 32) | left
        entropy = calculate_block_entropy(block_64bit)
        records.append(RoundRecord(round_idx, left, right, entropy))

    callback = collect_record if getattr(args, "verbose", False) else None

    cipher_chunks = encrypt(args.message, args.key, on_round=callback)
    ciphertext_bytes = list_int64_to_bytes(cipher_chunks)

    if records:
        print_round_table(records)

    print(ciphertext_bytes.hex())


def cmd_decrypt(args: argparse.Namespace):
    cipher_chunks = bytes_to_list_int64(args.ciphertext)
    plain_text = decrypt(cipher_chunks, args.key)
    print(plain_text)


def main():
    parser = argparse.ArgumentParser(description="DES CLI Tool")
    subparsers = parser.add_subparsers(dest="action", required=True)

    encrypt_p = subparsers.add_parser("encrypt", help="Encrypt a plaintext message")
    encrypt_p.add_argument(
        "key", type=parse_hex_key, help="64-bit key in HEX (e.g. 0x133457799BBCDFF1)"
    )
    encrypt_p.add_argument(
        "-v", "--verbose", action="store_true", help="Show round details and entropy"
    )
    encrypt_p.add_argument("message", type=str, help="Plaintext message to encrypt")
    encrypt_p.set_defaults(func=cmd_encrypt)

    decrypt_p = subparsers.add_parser(
        "decrypt", help="Decrypt a hex-encoded ciphertext"
    )
    decrypt_p.add_argument(
        "key", type=parse_hex_key, help="64-bit key in HEX (e.g. 0x133457799BBCDFF1)"
    )
    decrypt_p.add_argument("ciphertext", type=parse_ciphertext_bytes, help="Ciphertext in HEX format")
    decrypt_p.set_defaults(func=cmd_decrypt)

    args = parser.parse_args()

    args.func(args)


if __name__ == "__main__":
    main()
