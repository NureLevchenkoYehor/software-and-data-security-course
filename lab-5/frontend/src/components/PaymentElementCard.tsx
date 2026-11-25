import { useMemo } from "react";
import type { Stripe } from "@stripe/stripe-js";
import { Elements } from "@stripe/react-stripe-js";
import { Alert, Card, CardContent, CardHeader, Divider } from "@mui/material";
import {
  formatMoney,
  type CreatePaymentIntentResponse,
  type OrderRecord,
} from "../api";
import { CheckoutForm } from "./CheckoutForm";

interface PaymentElementCardProps {
  stripePromise: Promise<Stripe | null> | null;
  activeIntent: CreatePaymentIntentResponse | null;
  activeOrder: OrderRecord | null;
  onPaymentAttempted: (orderId: string) => void;
}

export function PaymentElementCard({
  stripePromise,
  activeIntent,
  activeOrder,
  onPaymentAttempted,
}: PaymentElementCardProps) {
  const elementsOptions = useMemo(
    () =>
      activeIntent
        ? {
            clientSecret: activeIntent.client_secret,
            appearance: {
              theme: "stripe" as const,
            },
          }
        : undefined,
    [activeIntent]
  );

  return (
    <Card sx={{ flex: 1 }}>
      <CardHeader
        title="2. Платіжна форма (Stripe Payment Element)"
        subheader="Введення реквізитів картки на стороні Stripe Sandbox"
      />
      <Divider />
      <CardContent>
        {activeIntent && stripePromise && elementsOptions ? (
          <Elements
            key={activeIntent.client_secret}
            stripe={stripePromise}
            options={elementsOptions}
          >
            <CheckoutForm
              orderId={activeIntent.order_id}
              formattedAmount={formatMoney(
                activeIntent.amount,
                activeIntent.currency
              )}
              disabled={activeOrder?.status === "paid"}
              onPaymentAttempted={onPaymentAttempted}
            />
          </Elements>
        ) : (
          <Alert severity="info">
            Створіть замовлення ліворуч, щоб ініціалізувати Stripe PaymentIntent
            і відобразити форму оплати.
          </Alert>
        )}
      </CardContent>
    </Card>
  );
}
