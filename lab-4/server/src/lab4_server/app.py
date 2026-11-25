import json
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Annotated

from fastapi import FastAPI, Header, HTTPException, Request, WebSocket, WebSocketDisconnect
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from lab4_server.chat import MAX_MESSAGE_LENGTH, MAX_NAME_LENGTH, Chat, Session
from lab4_server.secure import (
    InvalidPayload,
    decode_base64,
    decrypt_json,
    encode_base64,
    encrypt_json,
    handshake,
    load_private_key,
)

ALLOWED_ORIGINS = ["http://localhost:3000"]


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    try:
        app.state.private_key = load_private_key()
    except FileNotFoundError as error:
        raise RuntimeError(
            "RSA private key is missing. Run `python bin/generate_keys.py`."
        ) from error
    app.state.chat = Chat()
    yield


app = FastAPI(lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(RequestValidationError)
async def invalid_request_handler(request: Request, error: RequestValidationError) -> JSONResponse:
    return JSONResponse(status_code=400, content={"detail": "Invalid request."})


@app.exception_handler(InvalidPayload)
async def invalid_payload_handler(request: Request, error: InvalidPayload) -> JSONResponse:
    return JSONResponse(status_code=400, content={"detail": str(error)})


class HandshakeRequest(BaseModel):
    clientPub: str


class EncryptedRequest(BaseModel):
    iv: str
    ciphertext: str


@app.post("/api/handshake")
async def create_session(request: HandshakeRequest, http_request: Request) -> dict[str, str]:
    # Unlike lab-2, the session ID is returned in the response body instead of a
    # `sid` cookie. Cookies are shared by all tabs of a browser, so each new
    # handshake overwrote the previous tab's session; now every tab keeps its own
    # ID in memory and several users can chat from one browser.
    result = handshake(decode_base64(request.clientPub), http_request.app.state.private_key)
    chat: Chat = http_request.app.state.chat
    chat.sessions[result.session_id] = Session(aes_key=result.aes_key, fingerprint=result.fingerprint)
    return {
        "sessionId": result.session_id,
        "serverPub": encode_base64(result.server_public),
        "signature": encode_base64(result.signature),
    }


@app.post("/api/join")
async def join(
    request: EncryptedRequest,
    http_request: Request,
    x_session_id: Annotated[str, Header()],
) -> dict[str, str]:
    chat: Chat = http_request.app.state.chat
    session = chat.sessions.get(x_session_id)
    if session is None:
        raise HTTPException(status_code=401, detail="Handshake required.")

    payload = decrypt_json(session.aes_key, request.model_dump())
    name = payload.get("name")
    if not isinstance(name, str) or not 0 < len(name.strip()) <= MAX_NAME_LENGTH:
        raise HTTPException(status_code=400, detail=f"Name must be 1-{MAX_NAME_LENGTH} characters.")
    name = name.strip()
    if session.name != name and chat.name_taken(name):
        raise HTTPException(status_code=409, detail="This name is already taken.")

    session.name = name
    return encrypt_json(session.aes_key, {"name": name, "fingerprint": session.fingerprint})


@app.websocket("/api/chat")
async def chat_socket(websocket: WebSocket) -> None:
    if websocket.headers.get("origin") not in ALLOWED_ORIGINS:
        await websocket.close(code=1008)
        return
    await websocket.accept()

    # Browsers cannot set headers on a WebSocket, so the session ID is the first message.
    chat: Chat = websocket.app.state.chat
    try:
        first = await websocket.receive_json()
    except (WebSocketDisconnect, json.JSONDecodeError):
        return
    session_id = first.get("sessionId") if isinstance(first, dict) else None
    session = chat.sessions.get(session_id) if isinstance(session_id, str) else None
    if session is None or session.name is None or session.socket is not None:
        await websocket.close(code=4401, reason="Join the chat first.")
        return

    session.socket = websocket
    await chat.send(session, {"type": "history", "messages": list(chat.history)})
    await chat.broadcast({"type": "message", "message": chat.add_message(None, f"{session.name} joined")})
    await chat.broadcast({"type": "users", "users": chat.users()})

    try:
        while True:
            try:
                payload = decrypt_json(session.aes_key, await websocket.receive_json())
            except (InvalidPayload, json.JSONDecodeError):
                continue  # ignore frames that are not valid encrypted messages
            text = payload.get("text")
            if payload.get("type") != "message" or not isinstance(text, str):
                continue
            text = text.strip()
            if not text:
                continue
            message = chat.add_message(session.name, text[:MAX_MESSAGE_LENGTH])
            await chat.broadcast({"type": "message", "message": message})
    except WebSocketDisconnect:
        pass
    finally:
        del chat.sessions[session_id]
        await chat.broadcast({"type": "message", "message": chat.add_message(None, f"{session.name} left")})
        await chat.broadcast({"type": "users", "users": chat.users()})
