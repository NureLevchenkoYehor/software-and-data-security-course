from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Annotated

from fastapi import FastAPI, Form, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from lab3_server.signature import load_private_key, sign_digest, verify_digest
from lab3_server.tinyhash import SUPPORTED_BITS, TinyHash


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    try:
        app.state.private_key = load_private_key()
    except FileNotFoundError as error:
        raise RuntimeError(
            "RSA private key is missing. Run `python bin/generate_keys.py`."
        ) from error
    app.state.public_key = app.state.private_key.public_key()
    yield


app = FastAPI(lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class DigestResponse(BaseModel):
    name: str
    size: int
    bits: int
    digest: int
    binary: str
    hex: str


class SignResponse(DigestResponse):
    signature: str


class VerifyResponse(DigestResponse):
    valid: bool


class PublicKeyResponse(BaseModel):
    n: str
    e: int


async def digest_of(file: UploadFile, bits: int) -> DigestResponse:
    if bits not in SUPPORTED_BITS:
        raise HTTPException(status_code=400, detail=f"bits must be one of {SUPPORTED_BITS}.")
    data = await file.read()
    h = TinyHash(data, bits)
    return DigestResponse(
        name=file.filename or "",
        size=len(data),
        bits=bits,
        digest=h.intdigest(),
        binary=h.bindigest(),
        hex=h.hexdigest(),
    )


@app.post("/api/digest")
async def digest(file: UploadFile, bits: Annotated[int, Form()] = 8) -> DigestResponse:
    return await digest_of(file, bits)


@app.post("/api/sign")
async def sign(request: Request, file: UploadFile, bits: Annotated[int, Form()] = 8) -> SignResponse:
    result = await digest_of(file, bits)
    signature = sign_digest(result.digest, request.app.state.private_key)
    return SignResponse(**result.model_dump(), signature=format(signature, "x"))


@app.post("/api/verify")
async def verify(
    request: Request,
    file: UploadFile,
    signature: Annotated[str, Form()],
    bits: Annotated[int, Form()] = 8,
) -> VerifyResponse:
    result = await digest_of(file, bits)
    try:
        value = int(signature.strip().removeprefix("0x"), 16)
    except ValueError as error:
        raise HTTPException(status_code=400, detail="Signature must be a hex number.") from error
    valid = verify_digest(result.digest, value, request.app.state.public_key)
    return VerifyResponse(**result.model_dump(), valid=valid)


@app.get("/api/public-key")
async def public_key(request: Request) -> PublicKeyResponse:
    numbers = request.app.state.public_key.public_numbers()
    return PublicKeyResponse(n=format(numbers.n, "x"), e=numbers.e)
