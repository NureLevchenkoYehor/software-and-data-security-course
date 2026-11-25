"""Automatic collision: adjust a modified file so its digest equals the target.

A fixed-width nonce is placed in a part of the file that its format ignores:

* .docx (ZIP)  - archive comment at the end of the End of Central Directory record
* .png         - a tEXt chunk inserted right before IEND
* text/source  - a trailing comment line

The nonce always sits at the end of the file, so the hash state of the prefix
is computed once and only the short tail is re-hashed for every candidate.
"""

import struct
import zlib
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from lab3_server.tinyhash import TinyHash

NONCE_LEN = 16
MAX_TRIES = 1 << 20

Tail = Callable[[bytes], bytes]

COMMENT_PREFIXES = {
    ".py": b"#", ".sh": b"#", ".rb": b"#", ".toml": b"#", ".yml": b"#", ".yaml": b"#",
    ".c": b"//", ".h": b"//", ".cpp": b"//", ".cs": b"//", ".java": b"//", ".js": b"//",
    ".ts": b"//", ".tsx": b"//", ".go": b"//", ".rs": b"//", ".kt": b"//", ".swift": b"//",
    ".sql": b"--", ".lua": b"--", ".hs": b"--",
}


@dataclass
class CollisionResult:
    data: bytes
    digest: int
    tries: int
    nonce: bytes


def _split_docx(data: bytes) -> tuple[bytes, Tail]:
    eocd = data.rfind(b"PK\x05\x06")
    if eocd < 0 or len(data) - eocd < 22:
        raise ValueError("Not a ZIP/DOCX file: End of Central Directory not found.")
    # Comment length is the last field of the 22-byte EOCD record; drop any existing comment.
    prefix = data[: eocd + 20]
    return prefix, lambda nonce: struct.pack("<H", len(nonce)) + nonce


def _png_chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))


def _split_png(data: bytes) -> tuple[bytes, Tail]:
    iend = data.rfind(b"IEND")
    if not data.startswith(b"\x89PNG\r\n\x1a\n") or iend < 4:
        raise ValueError("Not a PNG file: IEND chunk not found.")
    prefix = data[: iend - 4]
    iend_chunk = _png_chunk(b"IEND", b"")
    return prefix, lambda nonce: _png_chunk(b"tEXt", b"nonce\x00" + nonce) + iend_chunk


def _split_text(data: bytes, comment: bytes) -> tuple[bytes, Tail]:
    prefix = data if data.endswith(b"\n") or not data else data + b"\n"
    return prefix, lambda nonce: comment + b" nonce: " + nonce + b"\n"


def split_carrier(data: bytes, suffix: str) -> tuple[bytes, Tail]:
    """Return (prefix, make_tail) such that prefix + make_tail(nonce) is a valid file."""
    suffix = suffix.lower()
    if suffix == ".docx":
        return _split_docx(data)
    if suffix == ".png":
        return _split_png(data)
    if suffix in COMMENT_PREFIXES:
        return _split_text(data, COMMENT_PREFIXES[suffix])
    raise ValueError(f"Unsupported file type: '{suffix}' (use .docx, .png or source code).")


def collide(data: bytes, suffix: str, target: int, bits: int) -> CollisionResult:
    """Find a nonce so that the digest of the modified file equals `target`."""
    prefix, make_tail = split_carrier(data, suffix)
    base = TinyHash(prefix, bits)

    for i in range(MAX_TRIES):
        nonce = format(i, f"0{NONCE_LEN}x").encode()
        tail = make_tail(nonce)
        h = base.copy()
        h.update(tail)
        if h.intdigest() == target:
            return CollisionResult(prefix + tail, target, i + 1, nonce)

    raise RuntimeError(f"No collision found in {MAX_TRIES} tries.")


def collide_files(original: Path, modified: Path, output: Path, bits: int) -> CollisionResult:
    target = TinyHash(original.read_bytes(), bits).intdigest()
    result = collide(modified.read_bytes(), modified.suffix, target, bits)
    output.write_bytes(result.data)
    return result
