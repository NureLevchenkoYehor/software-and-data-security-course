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
