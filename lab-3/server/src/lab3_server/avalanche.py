"""Avalanche test: change one byte of a message, measure how many digest bits change."""

import random
from dataclasses import dataclass

from lab3_server.tinyhash import SUPPORTED_BITS, TinyHash, fold

THRESHOLD = 0.30


@dataclass
class AvalancheResult:
    bits: int
    mean_changed: float  # average share of changed digest bits
    share_over_threshold: float  # share of trials where >= 30% of bits changed


def avalanche(trials: int = 300, seed: int | None = None) -> list[AvalancheResult]:
    rng = random.Random(seed)
    widths = (*SUPPORTED_BITS, 64)
    changed = {w: 0 for w in widths}
    over = {w: 0 for w in widths}

    for _ in range(trials):
        message = bytearray(rng.randbytes(rng.randint(16, 512)))
        before = TinyHash(bytes(message)).hash64()

        pos = rng.randrange(len(message))
        message[pos] = (message[pos] + rng.randint(1, 255)) % 256
        after = TinyHash(bytes(message)).hash64()

        for w in widths:
            share = (fold(before, w) ^ fold(after, w)).bit_count() / w
            changed[w] += share
            over[w] += share >= THRESHOLD

    return [AvalancheResult(w, changed[w] / trials, over[w] / trials) for w in widths]
