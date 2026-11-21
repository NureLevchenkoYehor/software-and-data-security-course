from collections.abc import Callable, Sequence

from des_constants import *

BITS_PER_BYTE = 8

RoundCallback = Callable[[int, int, int], None]


def list_int64_to_bytes(chunks: list[int]) -> bytes:
    return b"".join(
        chunk.to_bytes(BLOCK_SIZE_BYTES, byteorder="big") for chunk in chunks
    )


def bytes_to_list_int64(data: bytes) -> list[int]:
    return [
        int.from_bytes(data[i : i + BLOCK_SIZE_BYTES], byteorder="big")
        for i in range(0, len(data), BLOCK_SIZE_BYTES)
    ]


def permute(data: int, permutation: Sequence[int], total_input_bits: int = 64) -> int:
    result = 0
    for pos in permutation:
        shift_from = total_input_bits - pos
        bit = (data >> shift_from) & 1
        result = (result << 1) | bit
    return result


def substitute_6bit_with_4bit(data_6bit: int, substitution: Sequence[int]) -> int:
    msb = (data_6bit >> 5) & 1
    lsb = (data_6bit >> 0) & 1
    row = (msb << 1) | lsb
    col = (data_6bit >> 1) & 0b1111
    result_4 = substitution[(row << 4) | col]
    return result_4


def pad_bytes_pkcs5(data: bytes) -> bytes:
    padding_length = BLOCK_SIZE_BYTES - len(data) % BLOCK_SIZE_BYTES
    padding = bytes([padding_length]) * padding_length
    return data + padding


def unpad_bytes_pkcs5(data: bytes) -> bytes:
    padding_length = data[-1]
    return data[:-padding_length]


def left_rotate_28bit(value: int, shift: int) -> int:
    return ((value << shift) & 0x0FFFFFFF) | (value >> (28 - shift))


def generate_round_keys(key_64bit: int) -> list[int]:
    key_56bit = permute(key_64bit, PERMUTED_CHOICE_1)
    left_28bit = (key_56bit >> 28) & 0xFFFFFFF
    right_28bit = key_56bit & 0xFFFFFFF

    result = []
    for shift in SHIFT_SCHEDULE:
        right_28bit = left_rotate_28bit(right_28bit, shift)
        left_28bit = left_rotate_28bit(left_28bit, shift)
        concat_56bit = (left_28bit << 28) | right_28bit
        round_key_48bit = permute(concat_56bit, PERMUTED_CHOICE_2, total_input_bits=56)
        result.append(round_key_48bit)
    return result


def preprocess_message(raw: str) -> bytes:
    message_bytes = raw.encode(encoding="utf-8")
    return pad_bytes_pkcs5(message_bytes)


def feistel_function(right: int, round_key: int) -> int:
    expanded_48bit = permute(right, EXPANSION_FUNCTION, total_input_bits=32)
    xored_48bit = expanded_48bit ^ round_key

    sbox_output_32bit = 0
    for s_box_idx, s_box in enumerate(SUBSTITUTION_BOXES):
        chunk_6bit = (xored_48bit >> (42 - 6 * s_box_idx)) & 0b111111

        chunk_4bit = substitute_6bit_with_4bit(chunk_6bit, s_box)

        sbox_output_32bit = (sbox_output_32bit << 4) | chunk_4bit

    return permute(sbox_output_32bit, PERMUTATION, total_input_bits=32)


def encrypt(
    raw: str, master_key_64bit: int, on_round: RoundCallback | None = None
) -> list[int]:
    if master_key_64bit in INSECURE_KEYS:
        raise ValueError(f"Insecure key: {hex(master_key_64bit)} is not allowed in DES")
    message = preprocess_message(raw)
    round_keys = generate_round_keys(master_key_64bit)
    cipher: list[int] = []
    for chunk_offset in range(0, len(message), BLOCK_SIZE_BYTES):
        chunk_bytes = message[chunk_offset : chunk_offset + BLOCK_SIZE_BYTES]
        # NOTE: Check https://en.wikipedia.org/wiki/DES_supplementary_material for Big Endian order
        chunk_64bit = int.from_bytes(chunk_bytes, byteorder="big")

        chunk_64bit = permute(chunk_64bit, INITIAL_PERMUTATION)
        left_32bit = chunk_64bit >> 32
        right_32bit = chunk_64bit & 0xFFFFFFFF

        if on_round and chunk_offset == 0:
            on_round(0, left_32bit, right_32bit)

        for round_idx in range(TOTAL_ROUNDS):
            feistel_result_32bit = feistel_function(right_32bit, round_keys[round_idx])
            left_32bit, right_32bit = right_32bit, left_32bit ^ feistel_result_32bit
            if on_round and chunk_offset == 0:
                on_round(round_idx + 1, left_32bit, right_32bit)

        pre_output_64bit = (right_32bit << 32) | left_32bit
        cipher_chunk_64bit = permute(pre_output_64bit, FINAL_PERMUTATION)

        cipher.append(cipher_chunk_64bit)
    return cipher


def decrypt(cipher: list[int], master_key_64bit: int) -> str:
    round_keys = generate_round_keys(master_key_64bit)[::-1]
    message_chunks: list[int] = []
    for chunk_64bit in cipher:
        chunk_64bit = permute(chunk_64bit, INITIAL_PERMUTATION)
        left_32bit = chunk_64bit >> 32
        right_32bit = chunk_64bit & 0xFFFFFFFF

        for round_idx in range(TOTAL_ROUNDS):
            feistel_result_32bit = feistel_function(right_32bit, round_keys[round_idx])
            left_32bit, right_32bit = right_32bit, left_32bit ^ feistel_result_32bit

        pre_output_64bit = (right_32bit << 32) | left_32bit
        message_chunk_64bit = permute(pre_output_64bit, FINAL_PERMUTATION)

        message_chunks.append(message_chunk_64bit)
    message_bytes = list_int64_to_bytes(message_chunks)
    unpadded_bytes = unpad_bytes_pkcs5(message_bytes)
    return unpadded_bytes.decode(encoding="utf-8")
