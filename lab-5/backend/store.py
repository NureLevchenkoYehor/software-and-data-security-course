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
