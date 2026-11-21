import math


def binary_shannon_entropy(probability: float) -> float:
    if probability in (0.0, 1.0):
        return 0.0

    p = probability
    q = 1.0 - p
    return -(p * math.log2(p) + q * math.log2(q))


def calculate_block_entropy(block: int, total_bits: int = 64) -> float:
    bit_1_probability = block.bit_count() / total_bits
    return binary_shannon_entropy(bit_1_probability)
