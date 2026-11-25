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
