"""TinyHash: a hash function with a 2, 4 or 8 bit digest built on DES.

Scheme from the lab's theory (fig. 3.1):

    H_0 = I_H
    H_i = E_A(B) xor C

with A = H_{i-1} (key), B = M_i (encrypted block), C = M_i xor H_{i-1}:

    H_i = DES_{H_{i-1}}(M_i) xor M_i xor H_{i-1}

The message is split into 64-bit blocks (the DES block size). The last block
is padded with 0x80, zeros and the message length. The final 64-bit H is
XOR-folded down to the requested number of bits.
"""

from __future__ import annotations

from lab3_server.des import encrypt_block

BLOCK_SIZE = 8  # bytes, DES block
SUPPORTED_BITS = (2, 4, 8)
INITIAL_VALUE = 0x0123456789ABCDEF  # I_H, any fixed constant


def fold(value: int, bits: int) -> int:
    """XOR all `bits`-wide pieces of a 64-bit value together."""
    mask = (1 << bits) - 1
    result = 0
    for shift in range(0, 64, bits):
        result ^= (value >> shift) & mask
    return result


def pad(length: int) -> bytes:
    """Padding for a message of `length` bytes: 0x80, zeros, 64-bit length in bits."""
    zeros = (BLOCK_SIZE - (length + 1 + 8) % BLOCK_SIZE) % BLOCK_SIZE
    return b"\x80" + b"\x00" * zeros + (length * 8).to_bytes(8, "big")


class TinyHash:
    """Hasher that can be fed data in parts (like hashlib)."""

    def __init__(self, data: bytes = b"", bits: int = 8) -> None:
        if bits not in SUPPORTED_BITS:
            raise ValueError(f"bits must be one of {SUPPORTED_BITS}, got {bits}")
        self.bits = bits
        self.h = INITIAL_VALUE
        self.buffer = b""  # bytes waiting for a full block
        self.length = 0
        self.update(data)

    def compress(self, block: bytes) -> None:
        m = int.from_bytes(block, "big")
        self.h = encrypt_block(m, self.h) ^ m ^ self.h

    def update(self, data: bytes) -> None:
        self.length += len(data)
        data = self.buffer + data
        full = len(data) - len(data) % BLOCK_SIZE
        for i in range(0, full, BLOCK_SIZE):
            self.compress(data[i : i + BLOCK_SIZE])
        self.buffer = data[full:]

    def copy(self) -> TinyHash:
        clone = TinyHash(bits=self.bits)
        clone.h, clone.buffer, clone.length = self.h, self.buffer, self.length
        return clone

    def hash64(self) -> int:
        """Final 64-bit H (before folding). Does not change the hasher."""
        h = self.copy()
        rest = h.buffer + pad(h.length)
        for i in range(0, len(rest), BLOCK_SIZE):
            h.compress(rest[i : i + BLOCK_SIZE])
        return h.h

    def intdigest(self) -> int:
        return fold(self.hash64(), self.bits)

    def bindigest(self) -> str:
        return format(self.intdigest(), f"0{self.bits}b")

    def hexdigest(self) -> str:
        return format(self.intdigest(), f"0{(self.bits + 3) // 4}x")


def tinyhash(data: bytes, bits: int = 8) -> int:
    return TinyHash(data, bits).intdigest()
