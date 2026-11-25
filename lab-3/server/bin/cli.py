import argparse
import sys
from pathlib import Path

SERVER_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVER_ROOT / "src"))

from lab3_server.avalanche import THRESHOLD, avalanche
from lab3_server.collide import collide_files
from lab3_server.samples import generate
from lab3_server.signature import load_private_key, load_public_key, sign_digest, verify_digest
from lab3_server.tinyhash import SUPPORTED_BITS, TinyHash

DEFAULT_SAMPLES = SERVER_ROOT.parent / "samples"


def file_digest(path: Path, bits: int) -> TinyHash:
    return TinyHash(path.read_bytes(), bits)


def print_digest(path: Path, bits: int) -> None:
    h = file_digest(path, bits)
    print(f"{h.bindigest():>8}  0x{h.hexdigest():<2}  {path}")


def cmd_hash(args: argparse.Namespace) -> None:
    for path in args.files:
        print_digest(path, args.bits)


def cmd_avalanche(args: argparse.Namespace) -> None:
    print(f"Trials: {args.trials}, one random byte changed per trial")
    print(f"{'Bits':>4} | {'Mean changed':>12} | {f'Trials >= {THRESHOLD:.0%}':>14}")
    print("-" * 37)
    for r in avalanche(args.trials, args.seed):
        print(f"{r.bits:>4} | {r.mean_changed:>12.2%} | {r.share_over_threshold:>14.2%}")


def cmd_collide(args: argparse.Namespace) -> None:
    result = collide_files(args.original, args.modified, args.output, args.bits)
    print(f"Nonce: {result.nonce.decode()}, tries: {result.tries}")
    for path in (args.original, args.modified, args.output):
        print_digest(path, args.bits)


def cmd_samples(args: argparse.Namespace) -> None:
    pairs = generate(args.dir)
    collided = args.dir / "collided"
    collided.mkdir(exist_ok=True)

    print(f"{'File':<10} | {'Original':>8} | {'Modified':>8} | {'Collided':>8} | {'Tries':>5}")
    print("-" * 52)
    for original, modified in pairs:
        output = collided / original.name
        result = collide_files(original, modified, output, args.bits)
        digests = [file_digest(p, args.bits).bindigest() for p in (original, modified, output)]
        print(f"{original.name:<10} | {digests[0]:>8} | {digests[1]:>8} | {digests[2]:>8} | {result.tries:>5}")


def cmd_sign(args: argparse.Namespace) -> None:
    key = load_private_key(args.key) if args.key else load_private_key()
    h = file_digest(args.file, args.bits)
    signature = sign_digest(h.intdigest(), key)
    print(f"Digest:    {h.bindigest()} (0x{h.hexdigest()})")
    print(f"Signature: {signature:x}")
    if args.output:
        args.output.write_text(f"{signature:x}\n")


def cmd_verify(args: argparse.Namespace) -> None:
    key = load_public_key(args.key) if args.key else load_public_key()
    signature = int(args.signature.read_text().strip(), 16)
    h = file_digest(args.file, args.bits)
    valid = verify_digest(h.intdigest(), signature, key)
    print(f"Digest: {h.bindigest()} (0x{h.hexdigest()})")
    print("Signature is VALID" if valid else "Signature is INVALID")
    if not valid:
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(prog="cli.py", description="TinyHash: 2/4/8-bit hash function lab")
    sub = parser.add_subparsers(dest="command", required=True)

    def add_bits(p: argparse.ArgumentParser) -> None:
        p.add_argument("-b", "--bits", type=int, choices=SUPPORTED_BITS, default=8, help="digest size")

    p = sub.add_parser("hash", help="compute digests of files")
    p.add_argument("files", nargs="+", type=Path)
    add_bits(p)
    p.set_defaults(func=cmd_hash)

    p = sub.add_parser("avalanche", help="check how many digest bits change on a one-byte change")
    p.add_argument("-n", "--trials", type=int, default=300)
    p.add_argument("--seed", type=int)
    p.set_defaults(func=cmd_avalanche)

    p = sub.add_parser("collide", help="adjust MODIFIED so its digest equals ORIGINAL's")
    p.add_argument("original", type=Path)
    p.add_argument("modified", type=Path)
    p.add_argument("-o", "--output", type=Path, required=True)
    add_bits(p)
    p.set_defaults(func=cmd_collide)

    p = sub.add_parser("samples", help="generate sample documents and collide them")
    p.add_argument("-d", "--dir", type=Path, default=DEFAULT_SAMPLES)
    add_bits(p)
    p.set_defaults(func=cmd_samples)

    p = sub.add_parser("sign", help="sign a file digest with RSA")
    p.add_argument("file", type=Path)
    p.add_argument("-k", "--key", type=Path, help="private key PEM (default: server/private_key.pem)")
    p.add_argument("-o", "--output", type=Path, help="write signature (hex) to a file")
    add_bits(p)
    p.set_defaults(func=cmd_sign)

    p = sub.add_parser("verify", help="verify an RSA signature of a file digest")
    p.add_argument("file", type=Path)
    p.add_argument("signature", type=Path, help="file with the signature in hex")
    p.add_argument("-k", "--key", type=Path, help="public key PEM (default: server/public_key.pem)")
    add_bits(p)
    p.set_defaults(func=cmd_verify)

    args = parser.parse_args()
    try:
        args.func(args)
    except (ValueError, FileNotFoundError, RuntimeError) as error:
        parser.exit(2, f"error: {error}\n")


if __name__ == "__main__":
    main()
