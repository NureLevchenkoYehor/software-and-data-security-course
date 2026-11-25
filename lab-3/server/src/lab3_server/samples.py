"""Generate sample documents: original and modified versions of a .docx, a .py and a .png."""

import struct
import zlib
from pathlib import Path

from docx import Document

SOURCE_TEMPLATE = '''"""Simple deposit calculator."""

INTEREST_RATE = {rate}


def deposit(amount: float, years: int) -> float:
    for _ in range(years):
        amount *= 1 + INTEREST_RATE
    return round(amount, 2)


if __name__ == "__main__":
    print(deposit(10_000, 5))
'''


def make_docx(path: Path, amount: str) -> None:
    doc = Document()
    doc.add_heading("Payment order No. 42", level=1)
    doc.add_paragraph("Payer: LLC \"Example\".")
    doc.add_paragraph("Recipient: Kharkiv National University of Radio Electronics.")
    doc.add_paragraph(f"Amount to pay: {amount} UAH.")
    doc.add_paragraph("Purpose: tuition fee for the 2026/2027 academic year.")
    doc.save(str(path))


def make_source(path: Path, rate: str) -> None:
    path.write_text(SOURCE_TEMPLATE.format(rate=rate), encoding="utf-8")


def _png_chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))


def make_png(path: Path, square_color: tuple[int, int, int], size: int = 128) -> None:
    """Gradient background with a coloured square in the middle (8-bit RGB)."""
    rows = []
    lo, hi = size // 4, size * 3 // 4
    for y in range(size):
        row = bytearray(b"\x00")  # filter type: none
        for x in range(size):
            if lo <= x < hi and lo <= y < hi:
                row += bytes(square_color)
            else:
                row += bytes((x * 255 // size, y * 255 // size, 160))
        rows.append(bytes(row))

    header = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    data = (
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", header)
        + _png_chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
        + _png_chunk(b"IEND", b"")
    )
    path.write_bytes(data)


def generate(directory: Path) -> list[tuple[Path, Path]]:
    """Create original/ and modified/ sample files. Returns (original, modified) pairs."""
    original = directory / "original"
    modified = directory / "modified"
    original.mkdir(parents=True, exist_ok=True)
    modified.mkdir(parents=True, exist_ok=True)

    make_docx(original / "doc.docx", "1 000")
    make_docx(modified / "doc.docx", "9 000")
    make_source(original / "source.py", "0.05")
    make_source(modified / "source.py", "0.50")
    make_png(original / "image.png", (40, 120, 220))
    make_png(modified / "image.png", (220, 40, 40))

    names = ("doc.docx", "source.py", "image.png")
    return [(original / n, modified / n) for n in names]
