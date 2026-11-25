# Backend — Stripe PaymentIntents & Webhooks (FastAPI)

Серверна частина прототипу платіжного модуля для лабораторної роботи №5. Реалізує створення платіжних намірів (`PaymentIntents API`), In-Memory сховище замовлень та криптографічну верифікацію підпису вебхуків `Stripe-Signature` (`HMAC-SHA256`) по сирому тілу запиту.

## Передумови

- **Python** `>= 3.11` (перевірено на `3.14`) з модулем `venv`
- **Stripe CLI** (авторизований у режимі `sandbox` через `stripe login`)
- **curl** (для негативного тестування вебхуків)
- Змінні середовища Stripe, доступні в оточенні процесу:
  - `STRIPE_PUBLISHABLE_KEY` (`pk_test_...`)
  - `STRIPE_SECRET_KEY` (`sk_test_...`)
  - `STRIPE_WEBHOOK_SECRET` (`whsec_...` від `stripe listen`)

> **Примітка:** Якщо змінні збережені у файлі `.env` у корені репозиторію (`../.env`), перед запуском сервера їх потрібно експортувати в оточення оболонки.

## Структура

- `main.py` — FastAPI-додаток, CORS-політика, ендпоінти API та обробник вебхуків `/api/webhooks/stripe`
- `store.py` — потокобезпечне In-Memory сховище замовлень (`pending`, `paid`, `failed`) та оброблених `event_id` для ідемпотентності
- `requirements.txt` — залежності (`fastapi`, `uvicorn[standard]`, `stripe`)
- `test_webhooks.sh` — скрипт негативного тестування підпису вебхуків через `curl`
- `test_e2e_api.py` — скрипт перевірки повного життєвого циклу платежу та ідемпотентності через Stripe API / CLI

## Встановлення залежностей

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

## Запуск

### 1. Запуск FastAPI-сервера

Із кореня проєкту (експортуючи змінні середовища з `.env`):

```bash
set -a && source .env && set +a
cd backend
.venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000
```

Або напряму з переданими змінними середовища:

```bash
cd backend
STRIPE_PUBLISHABLE_KEY=pk_test_... \
STRIPE_SECRET_KEY=sk_test_... \
STRIPE_WEBHOOK_SECRET=whsec_... \
.venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000
```

Сервер буде доступний на `http://127.0.0.1:8000` (Swagger UI: `http://127.0.0.1:8000/docs`).

### 2. Запуск перенаправлення вебхуків Stripe CLI

В окремому терміналі:

```bash
stripe listen \
  --events payment_intent.succeeded,payment_intent.payment_failed \
  --forward-to http://127.0.0.1:8000/api/webhooks/stripe
```

## API ендпоінти

- `GET /api/health` — перевірка працездатності (`{"status": "ok"}`)
- `GET /api/config` — повертає публічний `publishable_key` для ініціалізації Stripe.js на фронтенді
- `GET /api/orders` — список усіх замовлень в In-Memory сховищі
- `GET /api/orders/{order_id}` — поточний статус і деталі конкретного замовлення
- `POST /api/orders/payment-intent` — створення замовлення (`pending`) та `PaymentIntent` із `metadata.order_id`
- `POST /api/webhooks/stripe` — прийом сирого тіла запиту (`raw bytes`), перевірка `Stripe-Signature` (`HTTP 400` при помилці), ідемпотентне оновлення статусу замовлення (`paid` / `failed`)

## Тестування

### Негативне тестування підписів вебхуків (`curl`)

Перевіряє відхилення (`HTTP 400`) при відсутності заголовка `Stripe-Signature`, підробленому тілі запиту, модифікованому підписі та застарілій мітці часу (`> 300 с`):

```bash
./backend/test_webhooks.sh
```

### Наскрізний API-тест та перевірка ідемпотентності

За запущених `uvicorn` та `stripe listen`:

```bash
set -a && source .env && set +a
backend/.venv/bin/python backend/test_e2e_api.py
```
