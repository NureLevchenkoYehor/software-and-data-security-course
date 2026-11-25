"""End-to-end API verification against live backend + Stripe Sandbox + stripe listen."""

from __future__ import annotations

import json
import os
import subprocess
import time
import urllib.request

import stripe

API_BASE = os.environ.get("API_BASE", "http://127.0.0.1:8000")
stripe.api_key = os.environ["STRIPE_SECRET_KEY"]


def http_json(method: str, path: str, body: dict | None = None) -> dict | list:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(
        f"{API_BASE}{path}",
        data=data,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode("utf-8"))


def wait_for_status(order_id: str, expected: str, timeout_s: float = 20.0) -> dict:
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        order = http_json("GET", f"/api/orders/{order_id}")
        assert isinstance(order, dict)
        if order["status"] == expected:
            return order
        time.sleep(0.5)
    raise TimeoutError(f"Order {order_id} did not reach status '{expected}' within {timeout_s}s")


def main() -> None:
    cfg = http_json("GET", "/api/config")
    assert isinstance(cfg, dict) and cfg["publishable_key"].startswith("pk_")
    print("Config OK, publishable_key prefix:", cfg["publishable_key"][:12] + "...")

    # 1. Positive flow
    order_a = http_json(
        "POST",
        "/api/orders/payment-intent",
        {"amount": 2500, "currency": "usd", "description": "E2E Positive Order"},
    )
    assert isinstance(order_a, dict)
    assert order_a["status"] == "pending"
    print(f"Created positive order {order_a['order_id']} ({order_a['payment_intent_id']}) -> pending")

    stripe.PaymentIntent.confirm(
        order_a["payment_intent_id"],
        payment_method="pm_card_visa",
        return_url="http://127.0.0.1:5173/",
    )
    paid_order = wait_for_status(order_a["order_id"], "paid")
    print(f"Webhook updated {paid_order['order_id']} -> paid (event={paid_order['last_event_id']})")

    # 2. Declined flow
    order_b = http_json(
        "POST",
        "/api/orders/payment-intent",
        {"amount": 4999, "currency": "usd", "description": "E2E Declined Order"},
    )
    assert isinstance(order_b, dict)
    assert order_b["status"] == "pending"
    print(f"Created declined order {order_b['order_id']} ({order_b['payment_intent_id']}) -> pending")

    try:
        stripe.PaymentIntent.confirm(
            order_b["payment_intent_id"],
            payment_method="pm_card_chargeDeclined",
            return_url="http://127.0.0.1:5173/",
        )
    except stripe.CardError as exc:
        print(f"Expected Stripe CardError on confirm: {exc.user_message}")

    failed_order = wait_for_status(order_b["order_id"], "failed")
    print(
        f"Webhook updated {failed_order['order_id']} -> failed "
        f"(event={failed_order['last_event_id']}, reason={failed_order['failure_reason']})"
    )

    # 3. Idempotency via stripe events resend
    event_id = paid_order["last_event_id"]
    assert event_id
    subprocess.run(["stripe", "events", "resend", event_id], check=True, stdout=subprocess.DEVNULL)
    time.sleep(1.5)
    paid_after_resend = http_json("GET", f"/api/orders/{order_a['order_id']}")
    assert isinstance(paid_after_resend, dict)
    assert paid_after_resend["status"] == "paid"
    print(f"Idempotency resend verified for {event_id} -> order remains paid")


if __name__ == "__main__":
    main()
