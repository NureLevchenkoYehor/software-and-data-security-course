# Frontend — Stripe Payment Element (Bun + React + TypeScript + MUI)

Клієнтський інтерфейс інтернет-магазину для лабораторної роботи №5. Побудований на React, TypeScript і Material UI з інтеграцією Stripe.js (`Payment Element`).

## Передумови

- **Bun** `>= 1.0` (перевірено на `1.4.5`)
- Запущений **backend** на `http://127.0.0.1:8000` (або `http://localhost:8000`) — фронтенд отримує `publishable_key` через `GET /api/config` і створює `PaymentIntent` через `POST /api/orders/payment-intent`
- Запущений `stripe listen --events payment_intent.succeeded,payment_intent.payment_failed --forward-to http://127.0.0.1:8000/api/webhooks/stripe` для автоматичного оновлення статусу замовлення після оплати

## Встановлення залежностей

```bash
cd frontend
bun install
```

## Запуск

### Режим розробки (Vite dev server)

```bash
cd frontend
bun run dev
```

Фронтенд запускається на `http://127.0.0.1:5173`.

### Перевірка типів і продакшн-збірка

```bash
cd frontend
bun run typecheck
bun run build
```

## Тестові картки Stripe Sandbox

Після створення замовлення у формі Stripe Payment Element можна використати тестові картки:

- **Успішна оплата:** `4242 4242 4242 4242` (будь-яка майбутня дата, наприклад `12/28`, CVC `424`) → статус зміниться на `Оплачено (paid)` після отримання вебхука `payment_intent.succeeded`.
- **Відхилений платіж:** `4000 0000 0000 0002` (будь-яка майбутня дата, CVC `424`) → статус зміниться на `Відхилено (failed)` із причиною відмови після отримання вебхука `payment_intent.payment_failed`.
