#import "@local/nure:0.3.0": *

#import style: spacing

#let w = work(..toml("doc.toml"))

#set document(..w.document)
#show: style.dstu.with(skip: 1)

#show raw.where(block: true): it => {
  if it.lang == none { return it }
  show raw.line: line => {
    box(width: 1.8em, align(right, str(line.number)))
    h(0.75em)
    line.body
  }
  it
}

#report.title-page(w)
#title-heading(w)

#v(-spacing)

== Мета роботи

Метою лабораторної роботи є вивчення можливостей використання криптографічних функцій для перевірки справжності проведеної оплати платіжною карткою в електронному магазині на прикладі інтеграції сучасної платіжної архітектури Stripe (`PaymentIntents API`, `Payment Element`, `Webhooks`) із криптографічною верифікацією підпису `HMAC-SHA256`.

== Хід роботи
#v(-spacing)

=== Налаштування тестового середовища Stripe Sandbox

Для виконання практичної частини роботи було підготовлено ізольоване тестове середовище платіжної системи Stripe, яке повністю відтворює поведінку реальної платіжної системи без списання коштів:
- створено обліковий запис у Stripe Dashboard та активовано ізольоване тестове середовище (Sandbox);
- отримано публічний (`pk_test_...`) і секретний (`sk_test_...`) ключі API для взаємодії клієнтської та серверної частин;
- встановлено утиліту командного рядка `stripe` CLI та виконано авторизацію командою `stripe login` з вибором режиму `sandbox`;
- за допомогою `stripe listen` отримано секрет підпису вебхуків (`whsec_...`) та перевірено його незмінність у межах активної пісочниці.

Для локальної розробки було обрано прийом серверних сповіщень через тунель `stripe listen --forward-to` замість реєстрації публічного HTTPS-ендпоінту, а змінні середовища (`STRIPE_PUBLISHABLE_KEY`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`) передано процесу бекенду через оточення виконання.

=== Архітектура та структура проєкту

Застосунок побудовано за клієнт-серверною архітектурою з чітким розділенням відповідальності між клієнтом, сервером магазину та інфраструктурою Stripe. Серверну частину реалізовано мовою Python на базі фреймворку FastAPI з використанням офіційного SDK `stripe` та потокобезпечного In-Memory сховища замовлень. Клієнтську частину розроблено мовою TypeScript у середовищі Bun із використанням бібліотеки React, компонентів інтерфейсу Material UI та пакетів `@stripe/stripe-js` і `@stripe/react-stripe-js`.

Структура проєкту має такий вигляд:

```
.
├── backend/
│   ├── README.md                      // інструкція запуску бекенду
│   ├── main.py                        // FastAPI-додаток: API та обробник вебхуків
│   ├── store.py                       // In-Memory сховище замовлень та ідемпотентності
│   ├── requirements.txt               // залежності Python (fastapi, uvicorn, stripe)
│   ├── test_webhooks.sh               // скрипт негативного тестування підписів через curl
│   └── test_e2e_api.py                // наскрізний API-тест та перевірка ідемпотентності
├── doc/
│   └── report/                        // звіт та ілюстративні матеріали
├── frontend/
│   ├── README.md                      // інструкція запуску фронтенду
│   ├── index.html                     // точка входу Vite
│   ├── vite.config.ts                 // конфігурація збірки Vite
│   ├── tsconfig.json                  // конфігурація TypeScript
│   ├── package.json                   // залежності фронтенду
│   └── src/
│       ├── api.ts                     // HTTP-клієнт до FastAPI та форматування сум
│       ├── App.tsx                    // кореневий компонент застосунку
│       ├── main.tsx                   // точка входу (ThemeProvider, CssBaseline)
│       ├── pages/
│       │   └── CheckoutPage.tsx       // сторінка оформлення та оплати замовлення
│       └── components/
│           ├── ActiveOrderSummary.tsx // картка деталей і статусу активного замовлення
│           ├── CheckoutForm.tsx       // форма PaymentElement та stripe.confirmPayment()
│           ├── OrderCreationCard.tsx  // форма формування замовлення та PaymentIntent
│           ├── OrdersHistoryTable.tsx // таблиця історії замовлень з In-Memory сховища
│           ├── OrderStatusChip.tsx    // індикатор статусу (pending / paid / failed)
│           └── PaymentElementCard.tsx // контейнер Stripe Elements для платіжної форми
└── README.md                          // загальний опис роботи та контрольні запитання
```

=== Платіжна форма та ініціалізація PaymentIntent

На відміну від застарілих підходів із перенаправленням або передачею реквізитів картки через сервер магазину, платіжну форму реалізовано через Stripe `PaymentIntents API` та вбудований компонент `Payment Element`. Це гарантує, що конфіденційні дані платіжної картки вводяться безпосередньо в ізольований iframe Stripe і ніколи не потрапляють на бекенд магазину.

Ініціалізація та проведення оплати відбуваються у декілька етапів:
- під час завантаження сторінки клієнт отримує публічний ключ `STRIPE_PUBLISHABLE_KEY` з ендпоінту `GET /api/config` та ініціалізує `loadStripe(...)`;
- користувач обирає товар або задає власну суму, валюту (`usd`, `eur`, `uah`) й опис у компоненті `OrderCreationCard`, після чого клієнт надсилає запит `POST /api/orders/payment-intent`;
- сервер створює запис замовлення у статусі `pending` в `InMemoryOrderStore`, викликає `stripe.PaymentIntent.create(...)` із передачею `order_id` у полі `metadata` та повертає клієнту `client_secret`;
- клієнт монтує контейнер `<Elements>` із отриманим `client_secret` та компонент `<PaymentElement>` у формі `CheckoutForm`;
- після натискання кнопки оплати викликається `stripe.confirmPayment(...)` із параметром `redirect: "if_required"`, а інтерфейс починає опитування `GET /api/orders/{order_id}` для відображення статусу, оновленого серверним вебхуком.

На @fig-initial[рисунку] показано початковий стан інтерфейсу платіжного модуля перед створенням замовлення, а на @fig-pending[рисунку] -- стан після створення замовлення `ORD-A528B894` (`pi_3UfOjfLPnicWsktA0X1x9MSQ`) у статусі `pending` із заповненою тестовою карткою Visa `4242 4242 4242 4242`.

#fig(path("assets/full-page-initial.png"), [Початковий стан інтерфейсу платіжного модуля], label: <fig-initial>)

#fig(
  path("assets/full-page-entered-successful-plus-visible-pending.png"),
  [Сформоване замовлення у статусі очікування та заповнений Stripe Payment Element],
  label: <fig-pending>,
)

Для зручності тестування різних платіжних сценаріїв у середовищі Sandbox використано вбудовану панель розробника Stripe Developers (@fig-dev-menu[рис.]), яка надає доступ до інспектора елементів та наборів тестових карток.

#fig(
  path("assets/special-stripe-dev-menu.png"),
  [Панель розробника Stripe Developers у режимі Sandbox],
  label: <fig-dev-menu>,
)

=== Обробник вебхуків та криптографічна перевірка підпису

Після завершення обробки платежу Stripe надсилає асинхронне сервер-серверне HTTP-сповіщення (webhook) на ендпоінт `POST /api/webhooks/stripe`. Критичною вимогою коректної криптографічної перевірки є зчитування тіла запиту виключно як необробленого потоку байтів (`raw_body = await request.body()`) без попереднього JSON-парсингу. Будь-яка пересеріалізація JSON змінює порядок ключів або форматування пробілів, що порушує цілісність підписаного повідомлення та призводить до відхилення легітимних запитів.

Верифікація заголовка `Stripe-Signature` виконується функцією `stripe.Webhook.construct_event(payload=raw_body, sig_header=sig_header, secret=settings.webhook_secret)` за алгоритмом `HMAC-SHA256`:
- із заголовка `Stripe-Signature` виділяються мітка часу `t` та значення підпису `v1`;
- формується рядок `signed_payload`, що поєднує мітку часу та сирі байти тіла запиту через крапку (`f"{t}.{raw_body}"`);
- обчислюється `HMAC-SHA256` із використанням секрету вебхука `STRIPE_WEBHOOK_SECRET` як ключа;
- обчислене значення порівнюється з підписом `v1` функцією порівняння з постійним часом (`hmac.compare_digest`), що захищає від атак за часом виконання;
- перевіряється, що різниця між поточним часом і міткою `t` не перевищує `300` секунд (захист від атак повторного відтворення).

За відсутності заголовка `Stripe-Signature`, некоректного тіла запиту або помилки `SignatureVerificationError` ендпоінт негайно відхиляє запит зі статусом `400 Bad Request`.

Після успішної верифікації підпису метод `process_webhook_event` сховища `InMemoryOrderStore` забезпечує ідемпотентність обробки: якщо `event_id` вже міститься у словнику `_processed_events`, повторне оновлення стану не виконується і повертається `200 OK` зі статусом `already_processed`. Для нових подій `payment_intent.succeeded` переводить замовлення у статус `paid`, а `payment_intent.payment_failed` -- у статус `failed` зі збереженням причини відмови з поля `last_payment_error.message`.

=== Результати практичного тестування

Під час практичної перевірки було виконано тестування як через графічний інтерфейс браузера з перенаправленням подій через `stripe listen --events payment_intent.succeeded,payment_intent.payment_failed --forward-to http://127.0.0.1:8000/api/webhooks/stripe`, так і за допомогою автоматизованих скриптів.

На @fig-success[рисунку] зафіксовано результат успішної оплати замовлення `ORD-A528B894` (`pi_3UfOjfLPnicWsktA0X1x9MSQ`): після надходження та верифікації події `evt_3UfOjfLPnicWsktA0WrwwnHU` статус замовлення автоматично змінився на `Оплачено (paid)`.

#fig(
  path("assets/full-page-completed-successful.png"),
  [Успішно оплачене замовлення після верифікації вебхука],
  label: <fig-success>,
)

На @fig-declined[рисунку] показано сценарій відхилення платежу тестовою карткою `4000 0000 0000 0002` для замовлення `ORD-65E16BD6` (`pi_3UfOlGLPnicWsktA142u70qb`): клієнтська форма відобразила помилку валідації картки, а серверний вебхук `evt_3UfOlGLPnicWsktA1w8fPyCk` перевів замовлення у статус `Відхилено (failed)` із повідомленням `Your card was declined.`.

#fig(
  path("assets/full-page-declined.png"),
  [Відхилений платіж та історія обох замовлень в інтерфейсі],
  label: <fig-declined>,
)

Додатково було виконано наскрізну перевірку життєвого циклу платежів та ідемпотентності скриптом `backend/test_e2e_api.py`. Результати виконання підтвердили коректність переходів станів та ігнорування дубліката події:

```
Config OK, publishable_key prefix: pk_test_51T5...
Created positive order ORD-66837568 (pi_3UfOntLPnicWsktA0GyqVzOy) -> pending
Webhook updated ORD-66837568 -> paid (event=evt_3UfOntLPnicWsktA0fPxXlZw)
Created declined order ORD-3442A022 (pi_3UfOnvLPnicWsktA1hQ2xXn7) -> pending
Expected Stripe CardError on confirm: Your card was declined.
Webhook updated ORD-3442A022 -> failed (event=evt_3UfOnvLPnicWsktA1exRiPNy, reason=Your card was declined.)
▸ Running in New business sandbox · sandbox (acct_1T5R5XLPnicWsktA)
Idempotency resend verified for evt_3UfOntLPnicWsktA0fPxXlZw -> order remains paid
```

Для перевірки стійкості вебхук-обробника до підробок та атак повторного відтворення було виконано негативне тестування утилітою `curl` за допомогою скрипта `backend/test_webhooks.sh`. Зведені результати наведено у @tab-negative[таблиці].

#tab(
  caption: [Результати негативного тестування ендпоінту вебхуків],
  columns: (auto, 1fr, auto, 1fr),
  header: ([№], [Сценарій тестування], [Код HTTP], [Відповідь сервера]),
  label: <tab-negative>,
  [1],
  [Відсутній заголовок `Stripe-Signature`],
  [400],
  [`Missing Stripe-Signature header.`],
  [2],
  [Підроблене тіло запиту (підпис від незміненого тіла)],
  [400],
  [`Invalid Stripe-Signature.`],
  [3],
  [Модифікований підпис `v1` у заголовку],
  [400],
  [`Invalid Stripe-Signature.`],
  [4],
  [Застаріла мітка часу (`t - 600` с) з валідним HMAC],
  [400],
  [`Invalid Stripe-Signature.`],
)

Виведення скрипта `backend/test_webhooks.sh`:

```
=== 1. Missing Stripe-Signature header ===
HTTP 400: {"detail":"Missing Stripe-Signature header."}
=== 2. Forged / tampered body ===
HTTP 400: {"detail":"Invalid Stripe-Signature."}
=== 3. Modified Stripe-Signature ===
HTTP 400: {"detail":"Invalid Stripe-Signature."}
=== 4. Stale timestamp (t - 600s) ===
HTTP 400: {"detail":"Invalid Stripe-Signature."}
All negative webhook signature tests returned HTTP 400.
```

== Висновки

У ході виконання лабораторної роботи було реалізовано та протестовано прототип платіжного модуля інтернет-магазину на базі архітектури Stripe (`PaymentIntents API`, `Payment Element`, `Webhooks`). Розділення обробки карткових даних (на боці Stripe Payment Element) та підтвердження стану оплати (через серверні вебхуки) забезпечило безпечну роботу з платіжними реквізитами.

Практичним тестуванням підтверджено, що зчитування необроблених байтів тіла запиту є необхідною умовою коректної перевірки підпису `HMAC-SHA256` у заголовку `Stripe-Signature`. Усі негативні запити з відсутнім заголовком, підробленим тілом, зміненим підписом або застарілою міткою часу було відхилено зі статусом `400 Bad Request`, а повторне надсилання вже обробленої події коректно проігноровано механізмом ідемпотентності за `event_id`.

== Контрольні запитання
#v(-spacing)

=== Поняття «банк-еквайєр» і «банк-емітент»

Банк-емітент -- банківська установа, яка випускає платіжну картку покупця, веде його картковий рахунок та несе відповідальність за авторизацію транзакцій (перевірку залишку коштів, лімітів і коректності автентифікаційних даних).

Банк-еквайєр -- банківська установа, яка обслуговує торговця (інтернет-магазин), забезпечує технічне приймання безготівкових платежів через платіжний шлюз, маршрутизацію запитів через міжнародні платіжні системи до банку-емітента та зарахування коштів на розрахунковий рахунок магазину.

=== Покрокова схема купівлі товару в інтернет-магазині

Процес оплати замовлення відбувається у такій послідовності:
- покупець формує замовлення у браузері, після чого сервер магазину створює `PaymentIntent` через Stripe API із прив'язкою `order_id` у метаданих і повертає `client_secret`;
- клієнтський застосунок монтує захищений інтерфейс Stripe `Payment Element` за отриманим `client_secret`;
- покупець вводить реквізити картки, а браузер надсилає їх безпосередньо до Stripe викликом `stripe.confirmPayment(...)`;
- Stripe передає запит на авторизацію через платіжну мережу до банку-еквайєра та банку-емітента, який схвалює або відхиляє операцію;
- Stripe формує подію результату (`payment_intent.succeeded` або `payment_intent.payment_failed`) і надсилає підписаний вебхук на сервер магазину;
- сервер магазину перевіряє підпис `Stripe-Signature`, ідемпотентно оновлює статус замовлення та надає покупцеві підтвердження.

=== Запобігання багаторазовій покупці того самого товару

Для захисту від повторного списання або дублювання обробки одного замовлення застосовується поєднання серверної ідемпотентності та унікальних ідентифікаторів:
- унікальний `order_id` передається в `metadata` при створенні `PaymentIntent`, а повторне створення замовлення з наявним `order_id` відхиляється зі статусом `409 Conflict`;
- обробник вебхуків фіксує кожен оброблений ідентифікатор події `event_id` у реєстрі `_processed_events` і при повторному надходженні тієї самої події повертає `200 OK` без повторної зміни статусу;
- клієнтська форма блокує кнопку повторної відправки під час виконання `confirmPayment` та після переходу замовлення у статус `paid`.

=== Визначення успішності оплати або відмови покупця

Надійним способом визначення остаточного результату оплати є приймання серверних вебхуків від платіжного провайдера (`payment_intent.succeeded` для успішної оплати та `payment_intent.payment_failed` для відмови), оскільки вони доставляються асинхронно навіть у випадку закриття вкладки браузера покупцем або проходження 3D Secure. Причина відмови фіксується з поля `last_payment_error.message` об'єкта `PaymentIntent`. Додатково стан транзакції можна перевірити синхронним запитом через `stripe.PaymentIntent.retrieve(...)`.

=== Поля запиту ініціалізації платежу на сервері

У реалізованому прототипі ендпоінт `POST /api/orders/payment-intent` приймає такі поля:
- `amount` (integer, обов'язкове): сума платежу в мінімальних одиницях валюти (центах або копійках);
- `currency` (string, обов'язкове): код валюти (`usd`, `eur` або `uah`);
- `description` (string, обов'язкове): текстовий опис замовлення;
- `order_id` (string, необов'язкове): власний унікальний ідентифікатор замовлення (за відсутності генерується автоматично у форматі `ORD-XXXXXXXX`).

=== Різниця між тестовим та реальним режимом роботи платіжної системи

У тестовому режимі (Sandbox / Test Mode) реальні фінансові списання не виконуються: використовуються ключі з префіксами `pk_test_` та `sk_test_`, спеціальні тестові номери карток для імітації успіху або відмови, а вебхуки можна локально перенаправляти через `stripe listen`. У реальному режимі (Live Mode) використовуються ключі `pk_live_` та `sk_live_`, проводяться справжні банківські операції з реальними коштами, а вебхуки надсилаються виключно на публічно доступний HTTPS-ендпоінт із жорсткими вимогами до надійності та перевірки підпису.

Програмний код серверної частини наведено у @app-server[Додатку А], а програмний код клієнтської частини — у @app-client[Додатку Б].

#show: style.appendices

= Програмний код серверної частини <app-server>

== Головний модуль FastAPI (`backend/main.py`)
```python
"""FastAPI backend for Stripe PaymentIntents & Webhook verification (Lab 5)."""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from typing import Literal, Optional

import stripe
from fastapi import FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, model_validator

from store import InMemoryOrderStore, OrderRecord

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("stripe_backend")

MIN_AMOUNT_BY_CURRENCY: dict[str, int] = {
    "usd": 100,   # $1.00 (above Stripe $0.50 minimum)
    "eur": 100,   # €1.00 (above Stripe €0.50 minimum)
    "uah": 2500,  # 25.00 UAH (above Stripe ~20 UAH equivalent minimum)
}


@dataclass(frozen=True)
class StripeSettings:
    """Stripe credentials loaded directly from process environment variables."""

    publishable_key: str
    secret_key: str
    webhook_secret: str

    @classmethod
    def from_env(cls) -> "StripeSettings":
        missing = [
            name
            for name in (
                "STRIPE_PUBLISHABLE_KEY",
                "STRIPE_SECRET_KEY",
                "STRIPE_WEBHOOK_SECRET",
            )
            if not os.environ.get(name, "").strip()
        ]
        if missing:
            raise RuntimeError(
                f"Missing required environment variables: {', '.join(missing)}"
            )
        return cls(
            publishable_key=os.environ["STRIPE_PUBLISHABLE_KEY"].strip(),
            secret_key=os.environ["STRIPE_SECRET_KEY"].strip(),
            webhook_secret=os.environ["STRIPE_WEBHOOK_SECRET"].strip(),
        )


settings = StripeSettings.from_env()
stripe.api_key = settings.secret_key

store = InMemoryOrderStore()

app = FastAPI(
    title="Lab 5 Stripe Payment Backend",
    description="PaymentIntents API & HMAC-SHA256 Webhook verification service",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class CreatePaymentIntentRequest(BaseModel):
    """Payload to create an order and initialize a Stripe PaymentIntent."""

    amount: int = Field(
        ...,
        gt=0,
        description="Payment amount in smallest currency unit (e.g., cents or kopiyok).",
    )
    currency: Literal["usd", "eur", "uah"] = Field(default="usd")
    description: str = Field(
        default="Оплата замовлення в інтернет-магазині",
        min_length=1,
        max_length=255,
    )
    order_id: Optional[str] = Field(default=None, min_length=3, max_length=64)

    @model_validator(mode="after")
    def validate_minimum_amount(self) -> "CreatePaymentIntentRequest":
        min_amount = MIN_AMOUNT_BY_CURRENCY[self.currency]
        if self.amount < min_amount:
            raise ValueError(
                f"Amount for {self.currency.upper()} must be at least {min_amount} minor units."
            )
        return self


class CreatePaymentIntentResponse(BaseModel):
    """Response returned to the frontend to mount Stripe Payment Element."""

    order_id: str
    client_secret: str
    payment_intent_id: str
    amount: int
    currency: str
    status: str


@app.get("/api/health")
def health() -> dict[str, str]:
    """Liveness probe endpoint."""
    return {"status": "ok"}


@app.get("/api/config")
def get_stripe_config() -> dict[str, str]:
    """Expose public Stripe publishable key for Stripe.js initialization."""
    return {"publishable_key": settings.publishable_key}


@app.get("/api/orders", response_model=list[OrderRecord])
def list_orders() -> list[OrderRecord]:
    """List all in-memory orders."""
    return store.list_orders()


@app.get("/api/orders/{order_id}", response_model=OrderRecord)
def get_order(order_id: str) -> OrderRecord:
    """Retrieve current status and details for a specific order."""
    order = store.get_order(order_id)
    if order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Order '{order_id}' not found.",
        )
    return order


@app.post(
    "/api/orders/payment-intent",
    response_model=CreatePaymentIntentResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_payment_intent(
    payload: CreatePaymentIntentRequest,
) -> CreatePaymentIntentResponse:
    """Create a pending order and initialize a Stripe PaymentIntent with order_id metadata."""
    try:
        order = store.create_order(
            amount=payload.amount,
            currency=payload.currency,
            description=payload.description.strip(),
            order_id=payload.order_id.strip() if payload.order_id else None,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail=str(exc)
        ) from exc

    try:
        intent = stripe.PaymentIntent.create(
            amount=order.amount,
            currency=order.currency,
            description=order.description,
            automatic_payment_methods={"enabled": True},
            metadata={"order_id": order.order_id},
        )
    except stripe.StripeError as exc:
        store.delete_order(order.order_id)
        logger.error(
            "Failed to create PaymentIntent for order_id=%s: %s",
            order.order_id,
            exc,
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Stripe error: {exc.user_message or str(exc)}",
        ) from exc

    store.attach_payment_intent(order.order_id, intent.id)
    logger.info(
        "Created PaymentIntent %s for order_id=%s (amount=%d %s, status=%s)",
        intent.id,
        order.order_id,
        order.amount,
        order.currency.upper(),
        order.status.value,
    )

    return CreatePaymentIntentResponse(
        order_id=order.order_id,
        client_secret=intent.client_secret,
        payment_intent_id=intent.id,
        amount=order.amount,
        currency=order.currency,
        status=order.status.value,
    )


@app.post("/api/webhooks/stripe")
async def stripe_webhook(request: Request) -> dict[str, str]:
    """Receive Stripe webhooks, verify HMAC-SHA256 Stripe-Signature on raw bytes, and update order status."""
    raw_body = await request.body()
    sig_header = request.headers.get("stripe-signature")

    if not sig_header:
        logger.warning("Rejected webhook: missing Stripe-Signature header.")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing Stripe-Signature header.",
        )

    try:
        event = stripe.Webhook.construct_event(
            payload=raw_body,
            sig_header=sig_header,
            secret=settings.webhook_secret,
        )
    except ValueError as exc:
        logger.warning("Rejected webhook: invalid payload (%s).", exc)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid webhook payload.",
        ) from exc
    except stripe.SignatureVerificationError as exc:
        logger.warning(
            "Rejected webhook: Stripe-Signature verification failed (%s).", exc
        )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid Stripe-Signature.",
        ) from exc

    event_dict: dict = event.to_dict() if hasattr(event, "to_dict") else dict(event)
    event_id: str = event_dict["id"]
    event_type: str = event_dict["type"]
    data_object: dict = event_dict["data"]["object"]
    metadata: dict = data_object.get("metadata") or {}
    order_id: Optional[str] = metadata.get("order_id")
    payment_intent_id: Optional[str] = data_object.get("id")

    failure_reason: Optional[str] = None
    if event_type == "payment_intent.payment_failed":
        last_error = data_object.get("last_payment_error") or {}
        failure_reason = last_error.get("message") or "Payment failed."

    already_processed, updated_order = store.process_webhook_event(
        event_id=event_id,
        event_type=event_type,
        order_id=order_id,
        payment_intent_id=payment_intent_id,
        failure_reason=failure_reason,
    )

    if already_processed:
        logger.info(
            "Idempotency check: duplicate webhook event_id=%s (%s) ignored.",
            event_id,
            event_type,
        )
        return {"status": "already_processed", "event_id": event_id}

    if updated_order is not None:
        logger.info(
            "Verified webhook event_id=%s (%s): order_id=%s updated to status=%s (pi=%s)",
            event_id,
            event_type,
            updated_order.order_id,
            updated_order.status.value,
            payment_intent_id,
        )
    else:
        logger.info(
            "Verified webhook event_id=%s (%s): no matching in-memory order (order_id=%s, pi=%s)",
            event_id,
            event_type,
            order_id,
            payment_intent_id,
        )

    return {
        "status": "processed",
        "event_id": event_id,
        "event_type": event_type,
    }
```

== Модуль In-Memory сховища (`backend/store.py`)
```python
"""In-memory order and webhook idempotency store."""

from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum
from threading import Lock
from typing import Optional
from uuid import uuid4

from pydantic import BaseModel


class OrderStatus(str, Enum):
    """Lifecycle states of a store order."""

    PENDING = "pending"
    PAID = "paid"
    FAILED = "failed"


class OrderRecord(BaseModel):
    """Representation of an order stored in memory."""

    order_id: str
    amount: int
    currency: str
    description: str
    status: OrderStatus
    payment_intent_id: Optional[str] = None
    failure_reason: Optional[str] = None
    last_event_id: Optional[str] = None
    created_at: str
    updated_at: str


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class InMemoryOrderStore:
    """Thread-safe in-memory storage for orders and processed Stripe event IDs."""

    def __init__(self) -> None:
        self._lock = Lock()
        self._orders: dict[str, OrderRecord] = {}
        self._intent_to_order: dict[str, str] = {}
        self._processed_events: dict[str, str] = {}

    def create_order(
        self,
        amount: int,
        currency: str,
        description: str,
        order_id: Optional[str] = None,
    ) -> OrderRecord:
        """Create a new order in pending status."""
        with self._lock:
            resolved_id = order_id or f"ORD-{uuid4().hex[:8].upper()}"
            if resolved_id in self._orders:
                raise ValueError(f"Order '{resolved_id}' already exists.")
            now = _utc_now_iso()
            record = OrderRecord(
                order_id=resolved_id,
                amount=amount,
                currency=currency.lower(),
                description=description,
                status=OrderStatus.PENDING,
                created_at=now,
                updated_at=now,
            )
            self._orders[resolved_id] = record
            return record.model_copy()

    def attach_payment_intent(self, order_id: str, payment_intent_id: str) -> OrderRecord:
        """Link a Stripe PaymentIntent ID to an existing order."""
        with self._lock:
            record = self._orders.get(order_id)
            if record is None:
                raise KeyError(f"Order '{order_id}' not found.")
            record.payment_intent_id = payment_intent_id
            record.updated_at = _utc_now_iso()
            self._intent_to_order[payment_intent_id] = order_id
            return record.model_copy()

    def delete_order(self, order_id: str) -> None:
        """Remove an order (used to roll back if PaymentIntent creation fails)."""
        with self._lock:
            record = self._orders.pop(order_id, None)
            if record and record.payment_intent_id:
                self._intent_to_order.pop(record.payment_intent_id, None)

    def get_order(self, order_id: str) -> Optional[OrderRecord]:
        """Return a copy of the order by ID, or None if missing."""
        with self._lock:
            record = self._orders.get(order_id)
            return record.model_copy() if record else None

    def list_orders(self) -> list[OrderRecord]:
        """Return all orders ordered newest-first."""
        with self._lock:
            return [
                record.model_copy()
                for record in reversed(list(self._orders.values()))
            ]

    def process_webhook_event(
        self,
        event_id: str,
        event_type: str,
        order_id: Optional[str],
        payment_intent_id: Optional[str],
        failure_reason: Optional[str] = None,
    ) -> tuple[bool, Optional[OrderRecord]]:
        """Apply a verified webhook event idempotently.

        Returns (already_processed, updated_order_or_none).
        """
        with self._lock:
            if event_id in self._processed_events:
                return True, None

            target_order_id = order_id
            if (not target_order_id or target_order_id not in self._orders) and payment_intent_id:
                target_order_id = self._intent_to_order.get(payment_intent_id)

            record = self._orders.get(target_order_id) if target_order_id else None

            if record is not None:
                if event_type == "payment_intent.succeeded":
                    record.status = OrderStatus.PAID
                    record.failure_reason = None
                elif event_type == "payment_intent.payment_failed":
                    record.status = OrderStatus.FAILED
                    record.failure_reason = failure_reason or "Payment was declined."
                record.last_event_id = event_id
                record.updated_at = _utc_now_iso()

            self._processed_events[event_id] = event_type
            return False, record.model_copy() if record else None
```

== Скрипт негативного тестування вебхуків (`backend/test_webhooks.sh`)
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WEBHOOK_URL="${WEBHOOK_URL:-http://127.0.0.1:8000/api/webhooks/stripe}"
PYTHON_BIN="${SCRIPT_DIR}/.venv/bin/python"

if [[ -z "${STRIPE_WEBHOOK_SECRET:-}" && -f "${ROOT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a
fi

if [[ -z "${STRIPE_WEBHOOK_SECRET:-}" ]]; then
  echo "ERROR: STRIPE_WEBHOOK_SECRET is not set." >&2
  exit 1
fi

sign_payload() {
  local ts="$1"
  local body="$2"
  TS="$ts" BODY="$body" "$PYTHON_BIN" - <<'PY'
import hashlib, hmac, os
ts = os.environ["TS"]
body = os.environ["BODY"]
secret = os.environ["STRIPE_WEBHOOK_SECRET"].encode("utf-8")
msg = f"{ts}.{body}".encode("utf-8")
print(hmac.new(secret, msg, hashlib.sha256).hexdigest())
PY
}

assert_status() {
  local label="$1"
  local expected="$2"
  shift 2
  local output
  output="$("$@")"
  local code="${output##*$'\n'}"
  local body="${output%$'\n'*}"
  echo "=== ${label} ==="
  echo "HTTP ${code}: ${body}"
  if [[ "$code" != "$expected" ]]; then
    echo "FAIL: expected HTTP ${expected}, got ${code}" >&2
    exit 1
  fi
}

ORIG_BODY='{"id":"evt_test_negative","type":"payment_intent.succeeded","data":{"object":{"id":"pi_test","metadata":{"order_id":"ORD-FAKE"}}}}'
TAMPERED_BODY='{"id":"evt_test_negative","type":"payment_intent.succeeded","data":{"object":{"id":"pi_tampered","metadata":{"order_id":"ORD-FAKE"}}}}'

NOW_TS="$(date +%s)"
VALID_SIG="$(sign_payload "$NOW_TS" "$ORIG_BODY")"
MODIFIED_SIG="0000${VALID_SIG:4}"

OLD_TS="$((NOW_TS - 600))"
OLD_SIG="$(sign_payload "$OLD_TS" "$ORIG_BODY")"

# 1. Missing Stripe-Signature header
assert_status "1. Missing Stripe-Signature header" "400" \
  curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$ORIG_BODY"

# 2. Forged / tampered request body (signed for ORIG_BODY, sent with TAMPERED_BODY)
assert_status "2. Forged / tampered body" "400" \
  curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: t=${NOW_TS},v1=${VALID_SIG}" \
  -d "$TAMPERED_BODY"

# 3. Modified signature
assert_status "3. Modified Stripe-Signature" "400" \
  curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: t=${NOW_TS},v1=${MODIFIED_SIG}" \
  -d "$ORIG_BODY"

# 4. Stale timestamp (>300s tolerance)
assert_status "4. Stale timestamp (t - 600s)" "400" \
  curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "Stripe-Signature: t=${OLD_TS},v1=${OLD_SIG}" \
  -d "$ORIG_BODY"

echo "All negative webhook signature tests returned HTTP 400."
```

= Програмний код клієнтської частини <app-client>

== Сторінка оформлення замовлення (`frontend/src/pages/CheckoutPage.tsx`)
```tsx
import { useCallback, useEffect, useState } from "react";
import { loadStripe, type Stripe } from "@stripe/stripe-js";
import { Alert, Box, Container, Stack, Typography } from "@mui/material";
import VerifiedUserIcon from "@mui/icons-material/VerifiedUser";

import {
  createPaymentIntent,
  fetchOrder,
  fetchOrders,
  fetchStripeConfig,
  type CreatePaymentIntentResponse,
  type Currency,
  type OrderRecord,
} from "../api";
import {
  OrderCreationCard,
  PRODUCT_PRESETS,
} from "../components/OrderCreationCard";
import { OrdersHistoryTable } from "../components/OrdersHistoryTable";
import { PaymentElementCard } from "../components/PaymentElementCard";

export function CheckoutPage() {
  const [stripePromise, setStripePromise] = useState<Promise<Stripe | null> | null>(
    null
  );
  const [configError, setConfigError] = useState<string | null>(null);

  const [selectedPreset, setSelectedPreset] = useState<string>("mouse");
  const [description, setDescription] = useState<string>(
    PRODUCT_PRESETS[1]!.description
  );
  const [amountMajor, setAmountMajor] = useState<string>(
    PRODUCT_PRESETS[1]!.amountMajor
  );
  const [currency, setCurrency] = useState<Currency>(
    PRODUCT_PRESETS[1]!.currency
  );

  const [creatingIntent, setCreatingIntent] = useState(false);
  const [createError, setCreateError] = useState<string | null>(null);

  const [activeIntent, setActiveIntent] =
    useState<CreatePaymentIntentResponse | null>(null);
  const [activeOrder, setActiveOrder] = useState<OrderRecord | null>(null);
  const [orders, setOrders] = useState<OrderRecord[]>([]);
  const [pollingOrderId, setPollingOrderId] = useState<string | null>(null);

  const refreshOrders = useCallback(async () => {
    try {
      const list = await fetchOrders();
      setOrders(list);
    } catch {
      // Ignore transient poll errors.
    }
  }, []);

  const refreshActiveOrder = useCallback(
    async (orderId: string) => {
      try {
        const order = await fetchOrder(orderId);
        setActiveOrder(order);
        await refreshOrders();
        if (order.status !== "pending") {
          setPollingOrderId(null);
        }
      } catch {
        // Ignore transient poll errors.
      }
    },
    [refreshOrders]
  );

  useEffect(() => {
    let cancelled = false;
    fetchStripeConfig()
      .then(({ publishable_key }) => {
        if (!cancelled) {
          setStripePromise(loadStripe(publishable_key));
        }
      })
      .catch((err: unknown) => {
        if (!cancelled) {
          setConfigError(
            err instanceof Error
              ? err.message
              : "Не вдалося отримати публічний ключ Stripe з бекенду."
          );
        }
      });
    void refreshOrders();
    return () => {
      cancelled = true;
    };
  }, [refreshOrders]);

  useEffect(() => {
    if (!pollingOrderId) {
      return;
    }
    let attempts = 0;
    const maxAttempts = 20;
    const interval = window.setInterval(() => {
      attempts += 1;
      void refreshActiveOrder(pollingOrderId);
      if (attempts >= maxAttempts) {
        setPollingOrderId(null);
      }
    }, 1000);

    return () => {
      window.clearInterval(interval);
    };
  }, [pollingOrderId, refreshActiveOrder]);

  const handlePresetChange = (presetId: string) => {
    setSelectedPreset(presetId);
    const preset = PRODUCT_PRESETS.find((item) => item.id === presetId);
    if (preset) {
      setDescription(preset.description);
      setAmountMajor(preset.amountMajor);
      setCurrency(preset.currency);
    }
  };

  const handleCreateOrder = async () => {
    setCreateError(null);
    const parsed = Number.parseFloat(amountMajor.replace(",", "."));
    if (!Number.isFinite(parsed) || parsed <= 0) {
      setCreateError("Вкажіть коректну суму оплати.");
      return;
    }
    const amountMinor = Math.round(parsed * 100);

    setCreatingIntent(true);
    try {
      const response = await createPaymentIntent({
        amount: amountMinor,
        currency,
        description: description.trim() || "Оплата замовлення",
      });
      setActiveIntent(response);
      setPollingOrderId(null);
      const order = await fetchOrder(response.order_id);
      setActiveOrder(order);
      await refreshOrders();
    } catch (err: unknown) {
      setCreateError(
        err instanceof Error
          ? err.message
          : "Помилка створення платіжного наміру."
      );
    } finally {
      setCreatingIntent(false);
    }
  };

  return (
    <Container maxWidth="lg" sx={{ py: 4 }}>
      <Stack spacing={3}>
        <Box>
          <Stack direction="row" spacing={1.5} sx={{ alignItems: "center" }}>
            <VerifiedUserIcon color="primary" fontSize="large" />
            <Typography variant="h4" sx={{ fontWeight: 700 }}>
              Платіжний модуль інтернет-магазину (Stripe)
            </Typography>
          </Stack>
          <Typography variant="body1" color="text.secondary" sx={{ mt: 0.5 }}>
            Лабораторна робота №5: PaymentIntents API, Payment Element та
            верифікація Webhook HMAC-SHA256
          </Typography>
        </Box>

        {configError && (
          <Alert severity="error">
            Помилка ініціалізації Stripe: {configError}
          </Alert>
        )}

        <Stack
          direction={{ xs: "column", md: "row" }}
          spacing={3}
          sx={{ alignItems: "stretch" }}
        >
          <OrderCreationCard
            selectedPreset={selectedPreset}
            description={description}
            amountMajor={amountMajor}
            currency={currency}
            createError={createError}
            creatingIntent={creatingIntent}
            stripeReady={Boolean(stripePromise)}
            activeOrder={activeOrder}
            onPresetChange={handlePresetChange}
            onDescriptionChange={setDescription}
            onAmountChange={setAmountMajor}
            onCurrencyChange={setCurrency}
            onCreateOrder={() => void handleCreateOrder()}
            onRefreshOrder={(orderId) => void refreshActiveOrder(orderId)}
          />

          <PaymentElementCard
            stripePromise={stripePromise}
            activeIntent={activeIntent}
            activeOrder={activeOrder}
            onPaymentAttempted={(orderId) => {
              void refreshActiveOrder(orderId);
              setPollingOrderId(orderId);
            }}
          />
        </Stack>

        <OrdersHistoryTable
          orders={orders}
          onRefresh={() => void refreshOrders()}
        />
      </Stack>
    </Container>
  );
}
```

== Компонент платіжної форми (`frontend/src/components/CheckoutForm.tsx`)
```tsx
import { useState, type FormEvent } from "react";
import {
  PaymentElement,
  useElements,
  useStripe,
} from "@stripe/react-stripe-js";
import { Alert, Box, Button, CircularProgress, Stack } from "@mui/material";
import LockIcon from "@mui/icons-material/Lock";

interface CheckoutFormProps {
  orderId: string;
  formattedAmount: string;
  disabled?: boolean;
  onPaymentAttempted: (orderId: string) => void;
}

export function CheckoutForm({
  orderId,
  formattedAmount,
  disabled = false,
  onPaymentAttempted,
}: CheckoutFormProps) {
  const stripe = useStripe();
  const elements = useElements();

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [clientMessage, setClientMessage] = useState<{
    severity: "error" | "info" | "success";
    text: string;
  } | null>(null);

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!stripe || !elements || isSubmitting || disabled) {
      return;
    }

    setIsSubmitting(true);
    setClientMessage(null);

    const { error, paymentIntent } = await stripe.confirmPayment({
      elements,
      confirmParams: {
        return_url: `${window.location.origin}/?order_id=${encodeURIComponent(orderId)}`,
      },
      redirect: "if_required",
    });

    if (error) {
      setClientMessage({
        severity: "error",
        text: error.message ?? "Платіж відхилено або виникла помилка перевірки картки.",
      });
      // Still poll backend because Stripe emits payment_intent.payment_failed webhook.
      onPaymentAttempted(orderId);
      setIsSubmitting(false);
      return;
    }

    if (paymentIntent?.status === "succeeded") {
      setClientMessage({
        severity: "info",
        text: "Картку підтверджено у Stripe. Очікуємо криптографічно верифікований webhook від сервера...",
      });
    } else if (paymentIntent) {
      setClientMessage({
        severity: "info",
        text: `Статус PaymentIntent: ${paymentIntent.status}. Перевіряємо оновлення замовлення на сервері...`,
      });
    }

    onPaymentAttempted(orderId);
    setIsSubmitting(false);
  };

  return (
    <Box component="form" onSubmit={handleSubmit} noValidate>
      <Stack spacing={2.5}>
        <PaymentElement options={{ layout: "tabs" }} />

        {clientMessage && (
          <Alert severity={clientMessage.severity}>{clientMessage.text}</Alert>
        )}

        <Button
          type="submit"
          variant="contained"
          size="large"
          disabled={!stripe || !elements || isSubmitting || disabled}
          startIcon={
            isSubmitting ? (
              <CircularProgress size={18} color="inherit" />
            ) : (
              <LockIcon />
            )
          }
          fullWidth
        >
          {isSubmitting
            ? "Обробка платежу..."
            : `Сплатити ${formattedAmount}`}
        </Button>
      </Stack>
    </Box>
  );
}
```
