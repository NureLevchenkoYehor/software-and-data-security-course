#import "@local/nure:0.3.0": *
#import style: spacing

#let w = work(
  ..toml("doc.toml"),
)

#set document(..w.document)
#show: style.dstu.with(skip: 1)

#report.title-page(w)

// Автоматична нумерація рядків у лістингах із вказаною мовою.
// Блоки без мови (дерева каталогів тощо) лишаються без номерів.
#show raw.where(block: true): it => {
  if it.lang == none { return it }
  show raw.line: line => {
    box(width: 1.5em, align(right, str(line.number)))
    h(0.75em)
    line.body
  }
  it
}

#title-heading(w)
#v(-spacing)

== Мета роботи
Метою роботи є отримання навичок безпечного обміну ключами по каналу зв'язку, які надалі можуть бути використані в алгоритмі шифрування, та програмна реалізація роботи алгоритму Діффі-Хеллмана.

== Хід роботи
#v(-spacing)
=== Теоретичні відомості
Алгоритм Діффі-Хеллмана призначений для обміну ключами і заснований на складності обчислення дискретних логарифмів @nure_method. Сторони знають загальнодоступні параметри: просте число $Q$ і його примітивний корінь $A$. Кожна сторона обирає випадковий закритий ключ $X < Q$, обчислює відкритий ключ $Y = A^X mod Q$ і передає його іншій стороні, після чого обидві сторони обчислюють однаковий спільний ключ $K = (Y_C)^(X_B) mod Q = (Y_B)^(X_C) mod Q$. Без автентифікації відкритих ключів алгоритм вразливий до атаки «man-in-the-middle» @stallings_crypto.

Робота є продовженням лабораторної роботи №2, у якій було реалізовано захищений обмін даними між клієнтом і сервером через відкритий канал зв'язку. Протокол рукостискання, криптографічні примітиви та стек технологій повністю взято з неї, тому теоретичні відомості про протокол ECDHE (варіант алгоритму Діффі-Хеллмана на еліптичних кривих), цифровий підпис RSA-PSS, функцію виведення ключів HKDF та шифрування AES-GCM тут не повторюються: їх наведено у звіті до лабораторної роботи №2.

=== Архітектура програмного забезпечення
Застосунок побудовано за клієнт-серверною архітектурою:
// dstu-ignore-next-line: citation-order
- серверна частина реалізована мовою Python на базі фреймворку FastAPI @fastapi_docs з використанням бібліотеки `cryptography`;
- клієнтська частина розроблена мовою TypeScript з використанням середовища виконання Bun, бібліотеки React, компонентів Material UI та вбудованого браузерного інтерфейсу Web Cryptography API @web_crypto.

Структура каталогів розробленого проєкту:

```
.
├── client/
│   ├── README.md                     // Інструкція запуску клієнта
│   └── src/
│       ├── App.tsx                   // Кореневий компонент React
│       ├── components/
│       │   ├── ChatRoom.tsx          // Вікно чату
│       │   ├── JoinForm.tsx          // Форма введення імені
│       │   ├── KeyExchangePanel.tsx  // Параметри обміну ключами
│       │   ├── MessageItem.tsx       // Повідомлення чату
│       │   └── UsersPanel.tsx        // Користувачі в мережі
│       ├── context/
│       │   └── SessionContext.tsx    // Сесія вкладки
│       ├── lib/
│       │   ├── chat.ts               // Підключення до чату
│       │   └── crypto.ts             // Рукостискання та AES-GCM
│       ├── pages/
│       │   └── MainPage.tsx          // Головна сторінка застосунку
│       └── secrets/
│           └── public_key.pem        // Відкритий ключ сервера
├── doc/                              // Методичні вказівки та звіт
├── README.md                         // Загальний опис роботи
└── server/
    ├── bin/
    │   ├── generate_keys.py          // Генерація пари ключів RSA
    │   └── main.py                   // Точка входу сервера FastAPI
    ├── pyproject.toml                // Залежності серверного пакета
    ├── README.md                     // Інструкція запуску сервера
    └── src/
        └── lab4_server/
            ├── __init__.py
            ├── app.py                // Маршрути API та WebSocket
            ├── chat.py               // Сесії, користувачі, історія
            ├── keys.py               // Генерація пари ключів RSA
            └── secure.py             // Рукостискання та AES-GCM
```

Сервер надає програмні інтерфейси, наведені в @endpoints-table[таблиці].

#tab(
  caption: [Специфікація програмних інтерфейсів сервера],
  columns: (1.4fr, 2fr, 4.5fr),
  header: ([Метод], [Шлях], [Призначення]),
  label: <endpoints-table>,
  [POST], [/api/handshake], [Автентифіковане узгодження сесійного ключа AES (як у лабораторній роботі №2)],
  [POST], [/api/join], [Приймання зашифрованого імені користувача],
  [WebSocket], [/api/chat], [Обмін зашифрованими повідомленнями чату в реальному часі @rfc6455],
)

Повний програмний код серверної частини наведено у @app-server[додатку], клієнтської -- у @app-client[додатку].

=== Обмін ключами Діффі-Хеллмана
Обмін ключами виконується так само, як у лабораторній роботі №2.

Відмінність від лабораторної роботи №2 полягає в способі передавання ідентифікатора сесії. У лабораторній роботі №2 сервер встановлював його у файлі cookie `sid`. Файли cookie спільні для всіх вкладок браузера, тому кожне нове рукостискання перезаписувало сесію попередньої вкладки. Тепер ідентифікатор сесії повертається в тілі відповіді на `/api/handshake` і зберігається лише в пам'яті вкладки разом із ключем AES. Завдяки цьому кожна вкладка має власну сесію та власний ключ, і кількох користувачів чату можна запустити в одному браузері. Ідентифікатор передається в заголовку `X-Session-Id` запиту `/api/join` та першим повідомленням після підключення до WebSocket, оскільки браузер не дозволяє задавати заголовки для WebSocket.

Для наочності клієнт і сервер обчислюють відбиток (fingerprint) спільного секрету -- перші 8 байтів його хешу SHA-256. Сервер повертає свій відбиток у зашифрованій відповіді на `/api/join`, а інтерфейс порівнює його з відбитком клієнта. Збіг відбитків підтверджує, що обидві сторони обчислили однаковий ключ, не розкриваючи сам ключ.

=== Чат для трьох і більше користувачів
Алгоритм Діффі-Хеллмана узгоджує ключ лише між двома сторонами, тому кожен користувач чату виконує обмін ключами з сервером і отримує власний сесійний ключ $K_1, K_2, K_3, dots$. Наскрізне шифрування між користувачами завданням не передбачено, тому сервер виступає посередником:
- користувач шифрує повідомлення своїм ключем $K_i$ і надсилає його через WebSocket;
- сервер розшифровує повідомлення ключем відправника, зберігає його у відкритому вигляді в історії (останні 100 повідомлень у пам'яті) та для кожного підключеного користувача $j$ шифрує його окремо ключем $K_j$ з новим вектором ініціалізації;
- кожен користувач розшифровує отримане повідомлення своїм ключем.

Отже, одне й те саме повідомлення в мережі має різний шифротекст для кожного отримувача. Через той самий зашифрований канал передаються історія повідомлень під час підключення, повідомлення про вхід і вихід користувачів та перелік користувачів у мережі.

Сервер перевіряє, що ім'я користувача унікальне та має довжину від 1 до 32 символів, а повідомлення -- не довше 1000 символів. Підключення до WebSocket приймаються лише зі сторінки клієнта (`http://localhost:3000`), оскільки політика CORS на WebSocket не поширюється. Після закриття вкладки сесію видаляють, а ім'я користувача звільняється.

=== Результати виконання
Інтерфейс складається з форми входу, вікна чату, переліку користувачів у мережі та панелі обміну ключами. Панель обміну ключами показує відкриті ключі ECDH клієнта й сервера, результат перевірки підпису сервера та відбитки спільного секрету. Форму входу після автоматичного рукостискання наведено на @fig-join[рисунку].

#figure(
  image("assets/join-form-with-name-entered.png", width: 100%),
  caption: [Форма входу до чату з результатами рукостискання],
) <fig-join>

Після входу до чату панель обміну ключами доповнюється відбитком, обчисленим сервером, і результатом порівняння з відбитком клієнта (@fig-empty-chat[рисунок]). Кожна вкладка має власну пару відкритих ключів і власний відбиток.

#figure(
  image("assets/empty-chat-second-user-pov.png", width: 100%),
  caption: [Вікно чату другого користувача після входу],
) <fig-empty-chat>

Натискання на повідомлення показує вектор ініціалізації та шифротекст, які отримала саме ця вкладка (@fig-messages[рисунок]). Для іншого користувача те саме повідомлення має інший шифротекст, оскільки сервер шифрує його окремо ключем кожного отримувача.

#figure(
  image("assets/chat-two-messages-expanded-second-user-pov.png", width: 100%),
  caption: [Повідомлення чату з розгорнутими зашифрованими кадрами],
) <fig-messages>

== Висновки
У результаті виконання лабораторної роботи було:
- реалізовано обмін ключами за алгоритмом Діффі-Хеллмана у варіанті ECDHE з автентифікацією сервера цифровим підписом RSA-PSS, що захищає від атаки «man-in-the-middle», на основі програмної реалізації лабораторної роботи №2;
- реалізовано чат для трьох і більше користувачів, у якому кожен користувач має власний сесійний ключ із сервером, а сервер повторно шифрує кожне повідомлення ключем кожного отримувача;
- замінено передавання ідентифікатора сесії через файли cookie на передавання в тілі відповіді, що дозволило запускати кількох користувачів в одному браузері;
- створено інтерфейс, який показує параметри обміну ключами, підтверджує, що клієнт і сервер обчислили однаковий ключ, та дозволяє переглянути зашифровані кадри повідомлень.

== Контрольні запитання
1\. Для чого створені алгоритми обміну ключами?

Алгоритми обміну ключами створені для того, щоб дві сторони могли отримати спільний секретний ключ, обмінюючись даними через відкритий канал зв'язку, яким може користуватися зловмисник. Симетричні шифри (наприклад, AES) швидкі, але потребують, щоб обидві сторони заздалегідь мали однаковий ключ. Передати ключ у відкритому вигляді неможливо, а окремий захищений канал для цього зазвичай відсутній. Алгоритм обміну ключами вирішує цю проблему: учасники передають лише відкриті значення, з яких кожен самостійно обчислює однаковий ключ, а сторонній спостерігач обчислити його не може. Отриманий ключ далі використовується в алгоритмі симетричного шифрування.

2\. Що мається на увазі під поняттям примітивного кореня простого числа?

Примітивним коренем простого числа $Q$ називається таке число $A$, степені якого за модулем $Q$ породжують усі цілі числа від $1$ до $Q - 1$. Тобто значення $A mod Q, A^2 mod Q, dots, A^(Q-1) mod Q$ є різними і є перестановкою чисел $1, 2, dots, Q - 1$. Наприклад, для $Q = 7$ число $A = 3$ є примітивним коренем, оскільки його степені дають $3, 2, 6, 4, 5, 1$, а число $2$ -- ні, оскільки його степені дають лише $2, 4, 1$.

Завдяки цій властивості для будь-якого $Y$ від $1$ до $Q - 1$ існує єдиний показник $X$, для якого $Y = A^X mod Q$, який називається дискретним логарифмом $Y$. Використання примітивного кореня гарантує, що відкриті ключі можуть набувати всіх можливих значень, а отже, простір для перебору максимальний.

3\. Як створюються пари ключів для обох сторін?

Обидві сторони знають загальнодоступні параметри: просте число $Q$ і його примітивний корінь $A$:
- користувач $B$ обирає випадкове число $X_B < Q$ (закритий ключ) і обчислює відкритий ключ $Y_B = A^(X_B) mod Q$;
- користувач $C$ незалежно обирає випадкове число $X_C < Q$ і обчислює $Y_C = A^(X_C) mod Q$.

Сторони обмінюються відкритими ключами $Y_B$ і $Y_C$, а закриті ключі залишають у таємниці. Після цього кожна сторона обчислює спільний ключ: $B$ -- як $K = (Y_C)^(X_B) mod Q$, а $C$ -- як $K = (Y_B)^(X_C) mod Q$. Обидва значення однакові, оскільки дорівнюють $A^(X_B X_C) mod Q$.

У цій роботі використано варіант ECDH, у якому роль закритого ключа відіграє випадкове число, а відкритим ключем є точка еліптичної кривої P-256, отримана множенням базової точки на це число. Обидві сторони генерують нову (ефемерну) пару ключів для кожної сесії.

4\. З чого виходить, що обмін ключами по алгоритму Діффі-Хеллмана вважається безпечним?

Безпека алгоритму Діффі-Хеллмана ґрунтується на складності задачі дискретного логарифмування. Зловмисник, який перехоплює обмін, знає лише $Q$, $A$, $Y_B$ і $Y_C$. Щоб обчислити ключ $K$, йому потрібно знайти хоча б один із закритих ключів, наприклад $X_C = "ind"_(A,Q) (Y_C)$. Піднесення до степеня за модулем виконується швидко, а для обернення цієї операції при великих простих числах (2048 біт і більше) не відомо ефективних алгоритмів, тому задача вважається практично нерозв'язною. Для ECDH аналогічною є задача дискретного логарифмування на еліптичній кривій, яка дозволяє досягти тієї ж стійкості з набагато коротшими ключами.

Водночас ця безпека стосується лише пасивного зловмисника, який може тільки прослуховувати канал. Від активного зловмисника алгоритм без автентифікації сторін не захищає (див. відповідь на питання 5).

5\. Що таке атака типу «man-in-the-middle»?

Атака «man-in-the-middle» («людина посередині») -- це активна атака, під час якої зловмисник розміщується між двома учасниками обміну, перехоплює їхні повідомлення та підміняє їх своїми, а учасники вважають, що спілкуються безпосередньо один з одним.

Для алгоритму Діффі-Хеллмана вона виглядає так: зловмисник перехоплює відкриті ключі $Y_B$ і $Y_C$, створює власну пару ключів і надсилає кожному з учасників свій відкритий ключ. У результаті $B$ узгоджує ключ зі зловмисником, і $C$ також узгоджує окремий ключ зі зловмисником. Зловмисник розшифровує всі повідомлення, читає або змінює їх і шифрує повторно для іншої сторони, а учасники не помічають підміни.

Захистом від такої атаки є автентифікація відкритих ключів. У цій роботі сервер підписує обидва відкриті ключі ECDH своїм статичним ключем RSA, а клієнт перевіряє підпис відомим йому відкритим ключем сервера. Зловмисник не може сформувати правильний підпис для підміненого ключа, тому клієнт виявить підміну та перерве з'єднання.

#bib(path("bibl.yml"), style: "3008")

#show: style.appendices

= Програмний код серверної частини <app-server>
// dstu-ignore-next-line: heading-orphan
== Рукостискання та шифрування AES-GCM (src/lab4_server/secure.py) <srv-secure>
```python
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
```

// dstu-ignore-next-line: heading-orphan
== Стан чату: сесії, користувачі, історія (src/lab4_server/chat.py) <srv-chat>
```python
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
```

// dstu-ignore-next-line: heading-orphan
== Маршрути API та обробник WebSocket (src/lab4_server/app.py) <srv-app>
```python
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
```

== Модуль генерації ключів RSA (src/lab4_server/keys.py) <srv-keys>
```python
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
```

// dstu-ignore-next-line: heading-orphan
== Скрипт генерації пари ключів RSA (bin/generate_keys.py) <srv-genkeys>
```python
from pathlib import Path
import sys

SERVER_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVER_ROOT / "src"))

from lab4_server.keys import generate_key_pair


if __name__ == "__main__":
    private_key_path = SERVER_ROOT / "private_key.pem"
    public_key_path = SERVER_ROOT / "public_key.pem"
    _, public_key_pem = generate_key_pair(private_key_path, public_key_path)
    print(public_key_pem.decode("ascii"))
```

== Точка входу сервера (bin/main.py) <srv-main>
```python
from pathlib import Path
import sys

SERVER_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SERVER_ROOT / "src"))

from lab4_server.app import app

__all__ = ["app"]
```

= Програмний код клієнтської частини <app-client>
// dstu-ignore-next-line: heading-orphan
== Рукостискання та шифрування AES-GCM (lib/crypto.ts) <cl-crypto>
```typescript
import serverPublicKeyPem from "@/secrets/public_key.pem" with { type: "text" };

export const API_URL = "http://localhost:8000";
export const WS_URL = "ws://localhost:8000/api/chat";

type HandshakeResponse = {
  sessionId: string;
  serverPub: string;
  signature: string;
};

type HandshakeResult = {
  sessionId: string;
  clientKeyPair: CryptoKeyPair;
  clientPublicBytes: Uint8Array<ArrayBuffer>;
  serverPublicBytes: Uint8Array<ArrayBuffer>;
  signature: Uint8Array<ArrayBuffer>;
};

/// Everything the UI needs about an established session.
export type Session = {
  sessionId: string;
  aesKey: CryptoKey;
  clientPublicKey: string;
  serverPublicKey: string;
  fingerprint: string;
};

/// An AES-GCM encrypted payload as it travels over the network.
export type Envelope = {
  iv: string;
  ciphertext: string;
};

/// Encodes a Uint8Array into a base64-encoded string.
export function encodeBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

/// Decodes a base64-encoded string into a Uint8Array.
export function decodeBase64(value: string): Uint8Array<ArrayBuffer> {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

/// Establishes a session key with the server using ECDH and HKDF.
export async function establishSession(): Promise<Session> {
  const handshake = await requestHandshake();
  await verifyServerSignature(handshake);
  const sharedSecret = await deriveSharedSecret(handshake);
  return {
    sessionId: handshake.sessionId,
    aesKey: await deriveSessionAesKey(sharedSecret),
    clientPublicKey: encodeBase64(handshake.clientPublicBytes),
    serverPublicKey: encodeBase64(handshake.serverPublicBytes),
    fingerprint: await fingerprintOf(sharedSecret),
  };
}

/// Encrypts a JSON value with the session key.
export async function encryptJson(aesKey: CryptoKey, value: unknown): Promise<Envelope> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const payload = new TextEncoder().encode(JSON.stringify(value));
  const ciphertext = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, aesKey, payload);
  return { iv: encodeBase64(iv), ciphertext: encodeBase64(new Uint8Array(ciphertext)) };
}

/// Decrypts an envelope with the session key and parses the JSON inside.
export async function decryptJson(aesKey: CryptoKey, envelope: Envelope): Promise<unknown> {
  const iv = decodeBase64(envelope.iv);
  if (iv.length !== 12) {
    throw new Error("Invalid IV.");
  }
  const plaintext = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv },
    aesKey,
    decodeBase64(envelope.ciphertext),
  );
  return JSON.parse(new TextDecoder().decode(plaintext));
}

export function isEnvelope(value: unknown): value is Envelope {
  return (
    typeof value === "object" &&
    value !== null &&
    "iv" in value &&
    typeof value.iv === "string" &&
    "ciphertext" in value &&
    typeof value.ciphertext === "string"
  );
}

/// Generates a new ECDH key pair, sends the public key to the server, and
/// receives the session ID, the server's public key and signature.
async function requestHandshake(): Promise<HandshakeResult> {
  const clientKeyPair = await crypto.subtle.generateKey(
    { name: "ECDH", namedCurve: "P-256" },
    false,
    ["deriveBits"],
  );
  const clientPublicBytes = new Uint8Array(
    await crypto.subtle.exportKey("raw", clientKeyPair.publicKey),
  );

  const response = await fetch(`${API_URL}/api/handshake`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ clientPub: encodeBase64(clientPublicBytes) }),
  });
  if (!response.ok) {
    throw new Error(`Handshake failed (${response.status}).`);
  }

  const data: unknown = await response.json();
  if (!isHandshakeResponse(data)) {
    throw new Error("The API returned an invalid handshake response.");
  }

  const serverPublicBytes = decodeBase64(data.serverPub);
  const signature = decodeBase64(data.signature);
  if (clientPublicBytes.length !== 65 || serverPublicBytes.length !== 65) {
    throw new Error("The API returned an invalid P-256 public key.");
  }

  return { sessionId: data.sessionId, clientKeyPair, clientPublicBytes, serverPublicBytes, signature };
}

/// Verifies the server's signature on the handshake response using the known
/// RSA public key.
async function verifyServerSignature(handshake: HandshakeResult): Promise<void> {
  const rsaPublicKey = await crypto.subtle.importKey(
    "spki",
    toArrayBuffer(pemToBytes(serverPublicKeyPem)),
    { name: "RSA-PSS", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const signedBytes = new Uint8Array(
    handshake.serverPublicBytes.length + handshake.clientPublicBytes.length,
  );
  signedBytes.set(handshake.serverPublicBytes);
  signedBytes.set(handshake.clientPublicBytes, handshake.serverPublicBytes.length);

  const signatureIsValid = await crypto.subtle.verify(
    { name: "RSA-PSS", saltLength: 32 },
    rsaPublicKey,
    handshake.signature,
    signedBytes,
  );
  if (!signatureIsValid) {
    throw new Error("The server handshake signature is invalid.");
  }
}

/// Computes the ECDH shared secret from the client's private key and the
/// server's public key.
async function deriveSharedSecret(handshake: HandshakeResult): Promise<ArrayBuffer> {
  const serverPublicKey = await crypto.subtle.importKey(
    "raw",
    handshake.serverPublicBytes,
    { name: "ECDH", namedCurve: "P-256" },
    false,
    [],
  );
  return crypto.subtle.deriveBits(
    { name: "ECDH", public: serverPublicKey },
    handshake.clientKeyPair.privateKey,
    256,
  );
}

/// Derives the AES-GCM session key from the shared secret using HKDF.
async function deriveSessionAesKey(sharedSecret: ArrayBuffer): Promise<CryptoKey> {
  const hkdfKey = await crypto.subtle.importKey("raw", sharedSecret, "HKDF", false, ["deriveKey"]);
  return crypto.subtle.deriveKey(
    {
      name: "HKDF",
      hash: "SHA-256",
      salt: new Uint8Array(32),
      info: new TextEncoder().encode("lab4-chat-v1"),
    },
    hkdfKey,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt", "decrypt"],
  );
}

/// Short public fingerprint of the shared secret (first 8 bytes of SHA-256),
/// used to compare the client's and the server's results.
async function fingerprintOf(sharedSecret: ArrayBuffer): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", sharedSecret));
  return Array.from(digest.slice(0, 8), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function isHandshakeResponse(value: unknown): value is HandshakeResponse {
  return (
    typeof value === "object" &&
    value !== null &&
    "sessionId" in value &&
    typeof value.sessionId === "string" &&
    "serverPub" in value &&
    typeof value.serverPub === "string" &&
    "signature" in value &&
    typeof value.signature === "string"
  );
}

/// Converts a Uint8Array into an ArrayBuffer.
function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const buffer = new ArrayBuffer(bytes.length);
  new Uint8Array(buffer).set(bytes);
  return buffer;
}

/// Converts a PEM-encoded public key into a Uint8Array.
function pemToBytes(pem: string): Uint8Array {
  const body = pem
    .replace("-----BEGIN PUBLIC KEY-----", "")
    .replace("-----END PUBLIC KEY-----", "")
    .replace(/\s/g, "");
  return decodeBase64(body);
}
```

// dstu-ignore-next-line: heading-orphan
== Підключення до чату (lib/chat.ts) <cl-chat>
```typescript
import { WS_URL, decryptJson, encryptJson, isEnvelope, type Envelope } from "@/lib/crypto";

export type ChatMessage = {
  id: number;
  author: string | null; // null for system events (join/leave)
  text: string;
  time: number;
  raw?: Envelope; // the encrypted frame this tab received, for inspection
};

type Handlers = {
  onHistory: (messages: ChatMessage[]) => void;
  onMessage: (message: ChatMessage) => void;
  onUsers: (users: string[]) => void;
  onClose: (reason: string) => void;
};

/// Opens the chat WebSocket. Browsers cannot set headers on a WebSocket, so
/// the session ID is sent as the first message; everything after it is
/// encrypted with the session key.
export function connectChat(sessionId: string, aesKey: CryptoKey, handlers: Handlers) {
  const socket = new WebSocket(WS_URL);

  socket.addEventListener("open", () => {
    socket.send(JSON.stringify({ sessionId }));
  });

  socket.addEventListener("message", async (event) => {
    const envelope: unknown = JSON.parse(String(event.data));
    if (!isEnvelope(envelope)) {
      return;
    }
    const payload = (await decryptJson(aesKey, envelope)) as Record<string, unknown>;
    if (payload.type === "history") {
      handlers.onHistory(payload.messages as ChatMessage[]);
    } else if (payload.type === "message") {
      handlers.onMessage({ ...(payload.message as ChatMessage), raw: envelope });
    } else if (payload.type === "users") {
      handlers.onUsers(payload.users as string[]);
    }
  });

  socket.addEventListener("close", (event) => {
    handlers.onClose(event.reason || "Connection closed.");
  });

  return {
    async send(text: string) {
      socket.send(JSON.stringify(await encryptJson(aesKey, { type: "message", text })));
    },
  };
}
```

// dstu-ignore-next-line: heading-orphan
== Контекст сесії вкладки (context/SessionContext.tsx) <cl-session>
```tsx
import { createContext, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import { establishSession, type Session } from "@/lib/crypto";

type SessionContextValue = {
  session: Session | null;
  error: string | null;
  isLoading: boolean;
};

/// A React context that provides this tab's session (ID, AES key and handshake
/// details), any handshake error, and the loading state.
const SessionContext = createContext<SessionContextValue | undefined>(undefined);

type Props = {
  children: ReactNode;
};

/// Establishes a session with the server once per tab. The session lives only
/// in memory, so every tab gets its own session ID and key.
export function SessionProvider({ children }: Props) {
  const [session, setSession] = useState<Session | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const handshakeStarted = useRef(false);

  useEffect(() => {
    if (handshakeStarted.current) {
      return;
    }
    handshakeStarted.current = true;

    async function initializeSession() {
      try {
        setSession(await establishSession());
      } catch (handshakeError) {
        setError(
          handshakeError instanceof Error
            ? handshakeError.message
            : "Could not complete the handshake.",
        );
      } finally {
        setIsLoading(false);
      }
    }

    void initializeSession();
  }, []);

  return (
    <SessionContext.Provider value={{ session, error, isLoading }}>
      {children}
    </SessionContext.Provider>
  );
}

export function useSession() {
  const context = useContext(SessionContext);
  if (context === undefined) {
    throw new Error("useSession must be used within a SessionProvider.");
  }
  return context;
}
```

// dstu-ignore-next-line: heading-orphan
== Форма введення імені (components/JoinForm.tsx) <cl-join>
```tsx
import { Alert, Button, Paper, Stack, TextField, Typography } from "@mui/material";
import { useState, type FormEvent } from "react";
import { useSession } from "@/context/SessionContext";
import { API_URL, decryptJson, encryptJson, isEnvelope } from "@/lib/crypto";

type Props = {
  onJoined: (name: string, serverFingerprint: string) => void;
};

type JoinResponse = {
  name: string;
  fingerprint: string;
};

function isJoinResponse(value: unknown): value is JoinResponse {
  return (
    typeof value === "object" &&
    value !== null &&
    "name" in value &&
    typeof value.name === "string" &&
    "fingerprint" in value &&
    typeof value.fingerprint === "string"
  );
}

export default function JoinForm({ onJoined }: Props) {
  const { session, error: handshakeError, isLoading } = useSession();
  const [name, setName] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!session) return;
    setIsSubmitting(true);
    setError(null);

    try {
      const response = await fetch(`${API_URL}/api/join`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-Session-Id": session.sessionId },
        body: JSON.stringify(await encryptJson(session.aesKey, { name })),
      });
      const data: unknown = await response.json();

      if (!response.ok) {
        const detail =
          typeof data === "object" && data !== null && "detail" in data && typeof data.detail === "string"
            ? data.detail
            : `Request failed (${response.status}).`;
        setError(detail);
        return;
      }
      if (!isEnvelope(data)) {
        throw new Error("The API returned an invalid join response.");
      }
      const payload = await decryptJson(session.aesKey, data);
      if (!isJoinResponse(payload)) {
        throw new Error("The API returned an invalid join response.");
      }
      onJoined(payload.name, payload.fingerprint);
    } catch (joinError) {
      setError(joinError instanceof Error ? joinError.message : "Could not join the chat.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <Paper elevation={4} sx={{ width: "100%", p: 4 }}>
      <Stack component="form" spacing={2} onSubmit={handleSubmit}>
        <Typography variant="h4" sx={{ fontWeight: 800 }}>
          Join the chat
        </Typography>

        {handshakeError && (
          <Alert severity="error">
            Secure session could not be initialized: {handshakeError} Reload the page to retry.
          </Alert>
        )}
        {error && <Alert severity="error">{error}</Alert>}

        <TextField
          required
          label="Name"
          value={name}
          slotProps={{ htmlInput: { maxLength: 32 } }}
          onChange={(event) => {
            setError(null);
            setName(event.target.value);
          }}
        />

        <Button type="submit" variant="contained" disabled={isSubmitting || isLoading || !session}>
          {isLoading ? "Establishing secure session..." : isSubmitting ? "Joining..." : "Join"}
        </Button>
      </Stack>
    </Paper>
  );
}
```

// dstu-ignore-next-line: heading-orphan
== Вікно чату (components/ChatRoom.tsx) <cl-room>
```tsx
import SendIcon from "@mui/icons-material/Send";
import { Alert, IconButton, Paper, Stack, TextField, Typography } from "@mui/material";
import { useEffect, useRef, useState, type FormEvent } from "react";
import MessageItem from "@/components/MessageItem";
import { connectChat, type ChatMessage } from "@/lib/chat";
import type { Session } from "@/lib/crypto";

const MAX_MESSAGE_LENGTH = 1000;

type Props = {
  session: Session;
  name: string;
  onUsers: (users: string[]) => void;
};

export default function ChatRoom({ session, name, onUsers }: Props) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [text, setText] = useState("");
  const [closed, setClosed] = useState<string | null>(null);
  const connection = useRef<ReturnType<typeof connectChat> | null>(null);
  const bottom = useRef<HTMLDivElement>(null);

  // Connect once per tab. The server ends the session when its socket closes,
  // so the socket must not be closed by React StrictMode's double mount; it
  // closes together with the tab.
  useEffect(() => {
    if (connection.current) {
      return;
    }
    connection.current = connectChat(session.sessionId, session.aesKey, {
      onHistory: setMessages,
      onMessage: (message) => setMessages((current) => [...current, message]),
      onUsers,
      onClose: setClosed,
    });
  }, [session, onUsers]);

  useEffect(() => {
    bottom.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!text.trim() || !connection.current) return;
    await connection.current.send(text);
    setText("");
  }

  return (
    <Paper elevation={4} sx={{ display: "flex", flexDirection: "column", height: "80vh", p: 2 }}>
      <Typography variant="h5" sx={{ fontWeight: 800, mb: 1 }}>
        Chat
      </Typography>
      <Typography variant="caption" color="text.secondary" sx={{ mb: 1 }}>
        Click a message to see the encrypted frame this tab received.
      </Typography>

      <Stack spacing={1} sx={{ flex: 1, overflowY: "auto", pr: 1 }}>
        {messages.map((message) => (
          <MessageItem key={message.id} message={message} mine={message.author === name} />
        ))}
        <div ref={bottom} />
      </Stack>

      {closed && (
        <Alert severity="warning" sx={{ mt: 1 }}>
          {closed} Reload the page to join again.
        </Alert>
      )}

      <Stack component="form" direction="row" spacing={1} onSubmit={handleSubmit} sx={{ mt: 1 }}>
        <TextField
          fullWidth
          size="small"
          placeholder="Message"
          value={text}
          disabled={closed !== null}
          slotProps={{ htmlInput: { maxLength: MAX_MESSAGE_LENGTH } }}
          onChange={(event) => setText(event.target.value)}
        />
        <IconButton type="submit" color="primary" disabled={closed !== null || !text.trim()}>
          <SendIcon />
        </IconButton>
      </Stack>
    </Paper>
  );
}
```

// dstu-ignore-next-line: heading-orphan
== Повідомлення чату (components/MessageItem.tsx) <cl-message>
```tsx
import { Box, Collapse, Paper, Stack, Typography } from "@mui/material";
import { useState } from "react";
import type { ChatMessage } from "@/lib/chat";

type Props = {
  message: ChatMessage;
  mine: boolean;
};

function formatTime(seconds: number) {
  return new Date(seconds * 1000).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

/// A chat message. Clicking it shows the encrypted frame this tab received.
export default function MessageItem({ message, mine }: Props) {
  const [showRaw, setShowRaw] = useState(false);

  if (message.author === null) {
    return (
      <Typography variant="caption" color="text.secondary" sx={{ textAlign: "center", py: 0.5 }}>
        {message.text} · {formatTime(message.time)}
      </Typography>
    );
  }

  return (
    <Box sx={{ display: "flex", justifyContent: mine ? "flex-end" : "flex-start" }}>
      <Paper
        elevation={0}
        onClick={() => setShowRaw((value) => !value)}
        sx={{
          px: 1.5,
          py: 1,
          maxWidth: "75%",
          minWidth: 0,
          cursor: message.raw ? "pointer" : "default",
          bgcolor: mine ? "primary.main" : "grey.100",
          color: mine ? "primary.contrastText" : "text.primary",
        }}
      >
        <Stack spacing={0.25}>
          <Typography variant="caption" sx={{ fontWeight: 700, opacity: 0.85 }}>
            {message.author} · {formatTime(message.time)}
          </Typography>
          <Typography variant="body1" sx={{ whiteSpace: "pre-wrap", wordBreak: "break-word" }}>
            {message.text}
          </Typography>
          {message.raw && (
            <Collapse in={showRaw}>
              <Typography
                variant="caption"
                component="div"
                sx={{ fontFamily: "monospace", wordBreak: "break-all", opacity: 0.85, mt: 0.5 }}
              >
                iv: {message.raw.iv}
                <br />
                ciphertext: {message.raw.ciphertext}
              </Typography>
            </Collapse>
          )}
        </Stack>
      </Paper>
    </Box>
  );
}
```

// dstu-ignore-next-line: heading-orphan
== Користувачі в мережі (components/UsersPanel.tsx) <cl-users>
```tsx
import PersonIcon from "@mui/icons-material/Person";
import { List, ListItem, ListItemIcon, ListItemText, Paper, Typography } from "@mui/material";

type Props = {
  users: string[];
  me: string;
};

export default function UsersPanel({ users, me }: Props) {
  return (
    <Paper variant="outlined" sx={{ p: 2 }}>
      <Typography variant="subtitle1" sx={{ fontWeight: 700 }}>
        Online ({users.length})
      </Typography>
      <List dense disablePadding>
        {users.map((user) => (
          <ListItem key={user} disableGutters>
            <ListItemIcon sx={{ minWidth: 32 }}>
              <PersonIcon fontSize="small" color={user === me ? "primary" : "inherit"} />
            </ListItemIcon>
            <ListItemText primary={user === me ? `${user} (you)` : user} />
          </ListItem>
        ))}
      </List>
    </Paper>
  );
}
```

// dstu-ignore-next-line: heading-orphan
== Панель обміну ключами (components/KeyExchangePanel.tsx) <cl-keys>
```tsx
import { Chip, Paper, Stack, Tooltip, Typography } from "@mui/material";
import { useSession } from "@/context/SessionContext";

type Props = {
  serverFingerprint: string | null;
};

function Field({ label, value }: { label: string; value: string }) {
  return (
    <Stack spacing={0.25}>
      <Typography variant="caption" color="text.secondary">
        {label}
      </Typography>
      <Tooltip title={value}>
        <Typography variant="body2" noWrap sx={{ fontFamily: "monospace" }}>
          {value}
        </Typography>
      </Tooltip>
    </Stack>
  );
}

/// Shows this tab's key exchange: both ECDH public keys, the signature check
/// and the fingerprints of the shared secret computed by each side.
export default function KeyExchangePanel({ serverFingerprint }: Props) {
  const { session, isLoading, error } = useSession();

  return (
    <Paper variant="outlined" sx={{ p: 2 }}>
      <Stack spacing={1.5}>
        <Typography variant="subtitle1" sx={{ fontWeight: 700 }}>
          Key exchange
        </Typography>

        {isLoading && <Chip label="Handshake in progress" />}
        {error && <Chip color="error" label="Handshake failed" />}

        {session && (
          <>
            <Chip color="success" variant="outlined" label="Server RSA-PSS signature verified" />
            <Field label="Client ECDH public key (P-256)" value={session.clientPublicKey} />
            <Field label="Server ECDH public key (P-256)" value={session.serverPublicKey} />
            <Field label="Shared secret fingerprint (client)" value={session.fingerprint} />
            {serverFingerprint && (
              <>
                <Field label="Shared secret fingerprint (server)" value={serverFingerprint} />
                {serverFingerprint === session.fingerprint ? (
                  <Chip color="success" label="Both sides derived the same key" />
                ) : (
                  <Chip color="error" label="Keys differ" />
                )}
              </>
            )}
          </>
        )}
      </Stack>
    </Paper>
  );
}
```

// dstu-ignore-next-line: heading-orphan
== Головна сторінка застосунку (pages/MainPage.tsx) <cl-main>
```tsx
import { Box, Stack } from "@mui/material";
import { useState } from "react";
import ChatRoom from "@/components/ChatRoom";
import JoinForm from "@/components/JoinForm";
import KeyExchangePanel from "@/components/KeyExchangePanel";
import UsersPanel from "@/components/UsersPanel";
import { useSession } from "@/context/SessionContext";

export default function MainPage() {
  const { session } = useSession();
  const [name, setName] = useState<string | null>(null);
  const [serverFingerprint, setServerFingerprint] = useState<string | null>(null);
  const [users, setUsers] = useState<string[]>([]);

  function onJoined(joinedName: string, fingerprint: string) {
    setName(joinedName);
    setServerFingerprint(fingerprint);
  }

  return (
    <Box sx={{ display: "flex", justifyContent: "center", p: 2 }}>
      <Stack
        direction={{ xs: "column", md: "row" }}
        spacing={2}
        sx={{ width: "100%", maxWidth: 1100, mt: 4, alignItems: "flex-start" }}
      >
        <Box sx={{ flex: 2, minWidth: 0, width: "100%" }}>
          {session && name ? (
            <ChatRoom session={session} name={name} onUsers={setUsers} />
          ) : (
            <JoinForm onJoined={onJoined} />
          )}
        </Box>
        <Stack spacing={2} sx={{ flex: 1, minWidth: 0, width: "100%" }}>
          {name && <UsersPanel users={users} me={name} />}
          <KeyExchangePanel serverFingerprint={serverFingerprint} />
        </Stack>
      </Stack>
    </Box>
  );
}
```

== Кореневий компонент (App.tsx) <cl-app>
```tsx
import { CssBaseline } from "@mui/material";
import MainPage from "@/pages/MainPage";
import { SessionProvider } from "@/context/SessionContext";

export default function App() {
  return (
    <SessionProvider>
      <CssBaseline />
      <MainPage />
    </SessionProvider>
  );
}
```

