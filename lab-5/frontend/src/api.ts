export type Currency = "usd" | "eur" | "uah";
export type OrderStatus = "pending" | "paid" | "failed";

export interface OrderRecord {
  order_id: string;
  amount: number;
  currency: Currency;
  description: string;
  status: OrderStatus;
  payment_intent_id: string | null;
  failure_reason: string | null;
  last_event_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreatePaymentIntentPayload {
  amount: number;
  currency: Currency;
  description: string;
}

export interface CreatePaymentIntentResponse {
  order_id: string;
  client_secret: string;
  payment_intent_id: string;
  amount: number;
  currency: Currency;
  status: OrderStatus;
}

const API_BASE_URL =
  window.location.hostname === "localhost"
    ? "http://localhost:8000"
    : "http://127.0.0.1:8000";

async function requestJson<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...init?.headers,
    },
  });

  if (!response.ok) {
    let message = `HTTP ${response.status}`;
    try {
      const body = (await response.json()) as { detail?: string };
      if (body.detail) {
        message = body.detail;
      }
    } catch {
      // Keep generic HTTP error message when response is not JSON.
    }
    throw new Error(message);
  }

  return (await response.json()) as T;
}

export function fetchStripeConfig(): Promise<{ publishable_key: string }> {
  return requestJson<{ publishable_key: string }>("/api/config");
}

export function createPaymentIntent(
  payload: CreatePaymentIntentPayload
): Promise<CreatePaymentIntentResponse> {
  return requestJson<CreatePaymentIntentResponse>("/api/orders/payment-intent", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function fetchOrder(orderId: string): Promise<OrderRecord> {
  return requestJson<OrderRecord>(`/api/orders/${encodeURIComponent(orderId)}`);
}

export function fetchOrders(): Promise<OrderRecord[]> {
  return requestJson<OrderRecord[]>("/api/orders");
}

export function formatMoney(amountMinor: number, currency: Currency): string {
  const major = (amountMinor / 100).toFixed(2);
  switch (currency) {
    case "usd":
      return `$${major}`;
    case "eur":
      return `€${major}`;
    case "uah":
      return `${major} ₴`;
  }
}
