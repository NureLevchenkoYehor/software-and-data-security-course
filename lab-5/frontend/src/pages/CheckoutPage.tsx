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
