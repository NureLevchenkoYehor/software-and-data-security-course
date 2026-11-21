from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

private_key_path = Path(__file__).with_name("private_key.pem")
if private_key_path.exists():
    raise FileExistsError(f"{private_key_path} already exists; refusing to overwrite it.")

private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
private_key_path.write_bytes(
    private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
)

public_key_pem = private_key.public_key().public_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PublicFormat.SubjectPublicKeyInfo,
)
print(public_key_pem.decode("ascii"))
