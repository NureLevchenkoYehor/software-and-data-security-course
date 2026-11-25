"""Chat state: sessions, users and message history.

Every user has their own session key with the server. A message is decrypted
with the sender's key, stored in plain form and re-encrypted with each
recipient's key before it is sent.
"""

import itertools
import time
from collections import deque
from dataclasses import dataclass, field

from fastapi import WebSocket

from lab4_server.secure import encrypt_json

HISTORY_SIZE = 100
MAX_NAME_LENGTH = 32
MAX_MESSAGE_LENGTH = 1000


@dataclass
class Session:
    aes_key: bytes
    fingerprint: str
    name: str | None = None
    socket: WebSocket | None = None


@dataclass
class Chat:
    sessions: dict[str, Session] = field(default_factory=dict)
    history: deque[dict] = field(default_factory=lambda: deque(maxlen=HISTORY_SIZE))
    _ids: itertools.count = field(default_factory=itertools.count)

    def users(self) -> list[str]:
        return sorted(s.name for s in self.sessions.values() if s.name and s.socket)

    def name_taken(self, name: str) -> bool:
        return any(s.name == name for s in self.sessions.values())

    def add_message(self, author: str | None, text: str) -> dict:
        """Store a message; author None means a system event (join/leave)."""
        message = {"id": next(self._ids), "author": author, "text": text, "time": time.time()}
        self.history.append(message)
        return message

    async def send(self, session: Session, payload: dict) -> None:
        if session.socket is not None:
            await session.socket.send_json(encrypt_json(session.aes_key, payload))

    async def broadcast(self, payload: dict) -> None:
        """Encrypt the payload separately for every connected user."""
        for session in list(self.sessions.values()):
            try:
                await self.send(session, payload)
            except Exception:
                pass  # socket closed while broadcasting; its own handler cleans it up
