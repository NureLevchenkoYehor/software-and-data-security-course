import base64
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, padding, rsa
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from fastapi.testclient import TestClient

import main


class LoginProtocolTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.private_key_path = Path(self.temp_dir.name) / "private_key.pem"
        self.private_key = rsa.generate_private_key(
            public_exponent=65537,
            key_size=2048,
        )
        self.private_key_path.write_bytes(
            self.private_key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.PKCS8,
                encryption_algorithm=serialization.NoEncryption(),
            )
        )
        self.key_path_patch = patch.object(main, "PRIVATE_KEY_PATH", self.private_key_path)
        self.key_path_patch.start()
        self.client = TestClient(main.app)
        self.client.__enter__()

    def tearDown(self) -> None:
        self.client.__exit__(None, None, None)
        self.key_path_patch.stop()
        self.temp_dir.cleanup()

    def establish_session(self) -> bytes:
        client_private_key = ec.generate_private_key(ec.SECP256R1())
        client_public_bytes = client_private_key.public_key().public_bytes(
            serialization.Encoding.X962,
            serialization.PublicFormat.UncompressedPoint,
        )
        response = self.client.post(
            "/api/handshake",
            json={"clientPub": base64.b64encode(client_public_bytes).decode("ascii")},
        )
        self.assertEqual(response.status_code, 200)

        server_public_bytes = base64.b64decode(response.json()["serverPub"])
        signature = base64.b64decode(response.json()["signature"])
        self.private_key.public_key().verify(
            signature,
            server_public_bytes + client_public_bytes,
            padding.PSS(
                mgf=padding.MGF1(hashes.SHA256()),
                salt_length=32,
            ),
            hashes.SHA256(),
        )

        server_public_key = ec.EllipticCurvePublicKey.from_encoded_point(
            ec.SECP256R1(), server_public_bytes
        )
        shared_secret = client_private_key.exchange(ec.ECDH(), server_public_key)
        aes_key = main.derive_aes_key(shared_secret)
        session_id = self.client.cookies["sid"]
        self.assertEqual(main.app.state.sessions[session_id], aes_key)
        return aes_key

    def encrypted_login(self, aes_key: bytes, login: str, password: str) -> dict[str, str]:
        iv = b"0123456789ab"
        plaintext = json.dumps({"login": login, "password": password}).encode("utf-8")
        ciphertext = AESGCM(aes_key).encrypt(iv, plaintext, None)
        return {
            "iv": base64.b64encode(iv).decode("ascii"),
            "ciphertext": base64.b64encode(ciphertext).decode("ascii"),
        }

    def test_handshake_signature_and_derived_session_key(self) -> None:
        self.establish_session()

    def test_login_and_corrupted_ciphertext(self) -> None:
        aes_key = self.establish_session()
        encrypted_request = self.encrypted_login(aes_key, "rimworld", "awolnation")

        response = self.client.post("/api/login", json=encrypted_request)
        self.assertEqual(response.status_code, 200)
        self.assertIsInstance(response.json().get("message"), str)

        corrupted_ciphertext = bytearray(
            base64.b64decode(encrypted_request["ciphertext"])
        )
        corrupted_ciphertext[-1] ^= 1
        encrypted_request["ciphertext"] = base64.b64encode(
            corrupted_ciphertext
        ).decode("ascii")
        response = self.client.post("/api/login", json=encrypted_request)
        self.assertEqual(response.status_code, 400)

    def test_login_requires_session_and_rejects_bad_request_shape(self) -> None:
        response = self.client.post("/api/login", json={"iv": "", "ciphertext": ""})
        self.assertEqual(response.status_code, 401)

        self.establish_session()
        response = self.client.post("/api/login", json={"iv": "invalid"})
        self.assertEqual(response.status_code, 400)
        response = self.client.post("/api/login", json={"iv": "", "ciphertext": ""})
        self.assertEqual(response.status_code, 400)

    def test_handshake_rejects_non_uncompressed_public_key(self) -> None:
        response = self.client.post(
            "/api/handshake",
            json={"clientPub": base64.b64encode(b"invalid").decode("ascii")},
        )
        self.assertEqual(response.status_code, 400)

    def test_cors_allows_credentials_for_client_origin(self) -> None:
        response = self.client.options(
            "/api/handshake",
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "content-type",
            },
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.headers["access-control-allow-origin"],
            "http://localhost:3000",
        )
        self.assertEqual(response.headers["access-control-allow-credentials"], "true")


if __name__ == "__main__":
    unittest.main()
