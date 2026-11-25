"""Handshake and AES-GCM helpers (from lab-2, with the session ID returned in the response)."""

import base64
import binascii
import hashlib
import json
import secrets
from dataclasses import dataclass
from pathlib import Path

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, padding, rsa
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

PRIVATE_KEY_PATH = Path(__file__).parents[2] / "private_key.pem"
HKDF_INFO = b"lab4-chat-v1"


class InvalidPayload(ValueError):
    """Raised when an encrypted payload cannot be decoded, decrypted or parsed."""


@dataclass
class HandshakeResult:
    session_id: str
    aes_key: bytes
    fingerprint: str
    server_public: bytes
    signature: bytes


def load_private_key() -> rsa.RSAPrivateKey:
    key = serialization.load_pem_private_key(PRIVATE_KEY_PATH.read_bytes(), password=None)
    if not isinstance(key, rsa.RSAPrivateKey) or key.key_size != 2048:
        raise RuntimeError("private_key.pem must contain an RSA-2048 private key.")
    if key.public_key().public_numbers().e != 65537:
        raise RuntimeError("private_key.pem must use public exponent 65537.")
    return key


def decode_base64(value: str) -> bytes:
    try:
        return base64.b64decode(value, validate=True)
    except (binascii.Error, ValueError) as error:
        raise InvalidPayload("Invalid base64.") from error


def encode_base64(value: bytes) -> str:
    return base64.b64encode(value).decode("ascii")


def derive_aes_key(shared_secret: bytes) -> bytes:
    return HKDF(
        algorithm=hashes.SHA256(),
        length=32,
        salt=bytes(32),
        info=HKDF_INFO,
    ).derive(shared_secret)


def key_fingerprint(shared_secret: bytes) -> str:
    """Short public fingerprint of the shared secret, to compare both sides' results."""
    return hashlib.sha256(shared_secret).hexdigest()[:16]


def handshake(client_public_bytes: bytes, private_key: rsa.RSAPrivateKey) -> HandshakeResult:
    """ECDHE (P-256) with the client, signed with the server's RSA key."""
    if len(client_public_bytes) != 65 or client_public_bytes[0] != 4:
        raise InvalidPayload("Invalid client public key.")
    try:
        client_public_key = ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), client_public_bytes)
    except ValueError as error:
        raise InvalidPayload("Invalid client public key.") from error

    server_private_key = ec.generate_private_key(ec.SECP256R1())
    server_public_bytes = server_private_key.public_key().public_bytes(
        serialization.Encoding.X962,
        serialization.PublicFormat.UncompressedPoint,
    )
    shared_secret = server_private_key.exchange(ec.ECDH(), client_public_key)
    signature = private_key.sign(
        server_public_bytes + client_public_bytes,
        padding.PSS(mgf=padding.MGF1(hashes.SHA256()), salt_length=32),
        hashes.SHA256(),
    )
    return HandshakeResult(
        session_id=secrets.token_urlsafe(32),
        aes_key=derive_aes_key(shared_secret),
        fingerprint=key_fingerprint(shared_secret),
        server_public=server_public_bytes,
        signature=signature,
    )


def encrypt_json(aes_key: bytes, payload: object) -> dict[str, str]:
    iv = secrets.token_bytes(12)
    ciphertext = AESGCM(aes_key).encrypt(iv, json.dumps(payload).encode("utf-8"), None)
    return {"iv": encode_base64(iv), "ciphertext": encode_base64(ciphertext)}


def decrypt_json(aes_key: bytes, envelope: object) -> dict:
    if not isinstance(envelope, dict):
        raise InvalidPayload("Invalid encrypted payload.")
    iv_text, ciphertext_text = envelope.get("iv"), envelope.get("ciphertext")
    if not isinstance(iv_text, str) or not isinstance(ciphertext_text, str):
        raise InvalidPayload("Invalid encrypted payload.")

    iv, ciphertext = decode_base64(iv_text), decode_base64(ciphertext_text)
    if len(iv) != 12 or len(ciphertext) < 16:
        raise InvalidPayload("Invalid encrypted payload.")
    try:
        payload = json.loads(AESGCM(aes_key).decrypt(iv, ciphertext, None))
    except (InvalidTag, ValueError, UnicodeDecodeError) as error:
        raise InvalidPayload("Invalid encrypted payload.") from error
    if not isinstance(payload, dict):
        raise InvalidPayload("Invalid encrypted payload.")
    return payload
