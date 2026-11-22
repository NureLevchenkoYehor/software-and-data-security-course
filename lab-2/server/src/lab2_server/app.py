import base64
import binascii
import json
import secrets
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from pathlib import Path

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, padding, rsa
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel


PAYLOAD_PATH = Path(__file__).parents[2] / "data" / "payload.txt"
PRIVATE_KEY_PATH = Path(__file__).parents[2] / "private_key.pem"


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    try:
        app.state.private_key = load_private_key()
    except FileNotFoundError as error:
        raise RuntimeError(
            "RSA private key is missing. Run `python bin/generate_keys.py`."
        ) from error
    app.state.sessions = {}
    yield




app = FastAPI(lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(RequestValidationError)
async def invalid_request_handler(request: Request, error: RequestValidationError) -> JSONResponse:
    return JSONResponse(status_code=400, content={"detail": "Invalid request."})


class HandshakeRequest(BaseModel):
    clientPub: str


class LoginRequest(BaseModel):
    iv: str
    ciphertext: str


@app.post("/api/handshake")
async def handshake(request: HandshakeRequest, response: Response, http_request: Request) -> dict[str, str]:
    client_public_bytes = decode_base64(request.clientPub)
    if len(client_public_bytes) != 65 or client_public_bytes[0] != 4:
        raise HTTPException(status_code=400, detail="Invalid client public key.")
    try:
        client_public_key = ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), client_public_bytes)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Invalid client public key.") from error

    server_private_key = ec.generate_private_key(ec.SECP256R1())
    server_public_bytes = server_private_key.public_key().public_bytes(
        serialization.Encoding.X962,
        serialization.PublicFormat.UncompressedPoint,
    )
    aes_key = derive_aes_key(server_private_key.exchange(ec.ECDH(), client_public_key))
    signature = http_request.app.state.private_key.sign(
        server_public_bytes + client_public_bytes,
        padding.PSS(mgf=padding.MGF1(hashes.SHA256()), salt_length=32),
        hashes.SHA256(),
    )

    session_id = secrets.token_urlsafe(32)
    http_request.app.state.sessions[session_id] = aes_key
    response.set_cookie(key="sid", value=session_id, httponly=True, samesite="lax", secure=False, path="/")
    return {
        "serverPub": base64.b64encode(server_public_bytes).decode("ascii"),
        "signature": base64.b64encode(signature).decode("ascii"),
    }


@app.post("/api/login")
async def login(request: LoginRequest, http_request: Request) -> dict[str, str]:
    session_id = http_request.cookies.get("sid")
    aes_key = http_request.app.state.sessions.get(session_id or "")
    if aes_key is None:
        raise HTTPException(status_code=401, detail="Handshake required.")

    iv = decode_base64(request.iv)
    ciphertext = decode_base64(request.ciphertext)
    if len(iv) != 12 or len(ciphertext) < 16:
        raise HTTPException(status_code=400, detail="Invalid encrypted request.")

    try:
        payload_bytes = AESGCM(aes_key).decrypt(iv, ciphertext, None)
        payload = json.loads(payload_bytes)
    except (InvalidTag, ValueError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise HTTPException(status_code=400, detail="Invalid encrypted request.") from error

    if (
        not isinstance(payload, dict)
        or not isinstance(payload.get("login"), str)
        or not isinstance(payload.get("password"), str)
    ):
        raise HTTPException(status_code=400, detail="Invalid encrypted request.")

    if payload["login"] != "rimworld" or payload["password"] != "awolnation":
        raise HTTPException(status_code=401, detail="Invalid login or password.")

    with open(PAYLOAD_PATH, "r", encoding="utf-8") as file:
        content = file.read()

    response_iv = secrets.token_bytes(12)
    response_ciphertext = AESGCM(aes_key).encrypt(
        response_iv,
        content.encode("utf-8"),
        None,
    )
    return {
        "iv": base64.b64encode(response_iv).decode("ascii"),
        "ciphertext": base64.b64encode(response_ciphertext).decode("ascii"),
    }


def decode_base64(value: str) -> bytes:
    try:
        return base64.b64decode(value, validate=True)
    except (binascii.Error, ValueError) as error:
        raise HTTPException(status_code=400, detail="Invalid request.") from error


def derive_aes_key(shared_secret: bytes) -> bytes:
    return HKDF(
        algorithm=hashes.SHA256(),
        length=32,
        salt=bytes(32),
        info=b"lab2-login-v1",
    ).derive(shared_secret)


def load_private_key() -> rsa.RSAPrivateKey:
    key = serialization.load_pem_private_key(PRIVATE_KEY_PATH.read_bytes(), password=None)
    if not isinstance(key, rsa.RSAPrivateKey) or key.key_size != 2048:
        raise RuntimeError("private_key.pem must contain an RSA-2048 private key.")
    if key.public_key().public_numbers().e != 65537:
        raise RuntimeError("private_key.pem must use public exponent 65537.")
    return key