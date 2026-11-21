# Лабораторна робота 2. Серверна частина

## Як запустити

1. Ініціалізувати середовище Python `python -m venv .venv`.
2. Встановити залежності `pip install .`
3. Згенерувати ключі командою `python generate_keys.py`. Скопіювати виведений відкритий PEM у `client/src/secrets/serverPublicKey.ts`. Приватний ключ створюється як `private_key.pem` і не повинен потрапляти в git.
4. Запустити `fastapi dev main.py`.

Якщо створюєте іншу пару ключів, оновіть відкритий ключ у клієнті. Сервер завантажує приватний ключ під час запуску.

## Перевірки

Запустити серверні тести з каталогу `server`: `python -m unittest discover -s tests`.

## Використана криптографічна бібліотека

Для ECDH, RSA-PSS, HKDF і AES-GCM використовується `cryptography` ([документація](https://cryptography.io/en/latest/)).
