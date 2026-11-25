from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

"""Generate and persist an RSA-2048 key pair."""
def generate_key_pair(
    private_key_path: Path,
    public_key_path: Path,
) -> tuple[bytes, bytes]:
    for key_path in (private_key_path, public_key_path):
        if key_path.exists():
            raise FileExistsError(
                f"{key_path} already exists; refusing to overwrite it."
            )

    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    private_key_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    public_key_pem = private_key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )

    private_key_path.write_bytes(private_key_pem)
    public_key_path.write_bytes(public_key_pem)

    return private_key_pem, public_key_pem
