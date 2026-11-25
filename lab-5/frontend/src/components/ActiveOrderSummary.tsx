import { Alert, Box, Button, Paper, Stack, Typography } from "@mui/material";
import RefreshIcon from "@mui/icons-material/Refresh";
import { formatMoney, type OrderRecord } from "../api";
import { OrderStatusChip } from "./OrderStatusChip";

interface ActiveOrderSummaryProps {
  order: OrderRecord;
  onRefresh: (orderId: string) => void;
}

export function ActiveOrderSummary({
  order,
  onRefresh,
}: ActiveOrderSummaryProps) {
  return (
    <Paper variant="outlined" sx={{ p: 2, bgcolor: "grey.50" }}>
      <Stack spacing={1}>
        <Stack
          direction="row"
          sx={{ justifyContent: "space-between", alignItems: "center" }}
        >
          <Typography variant="subtitle2" sx={{ fontWeight: 700 }}>
            Замовлення: {order.order_id}
          </Typography>
          <OrderStatusChip status={order.status} />
        </Stack>

        <Typography variant="body2" color="text.secondary">
          Товар: {order.description}
        </Typography>

        <Typography variant="body2" color="text.secondary">
          Сума: <strong>{formatMoney(order.amount, order.currency)}</strong>
        </Typography>

        <Typography
          variant="caption"
          color="text.secondary"
          sx={{ fontFamily: "monospace" }}
        >
          PaymentIntent: {order.payment_intent_id}
        </Typography>

        {order.last_event_id && (
          <Typography
            variant="caption"
            color="text.secondary"
            sx={{ fontFamily: "monospace" }}
          >
            Webhook Event: {order.last_event_id}
          </Typography>
        )}

        {order.failure_reason && (
          <Alert severity="error" sx={{ mt: 1 }}>
            Причина відмови (з webhook): {order.failure_reason}
          </Alert>
        )}

        {order.status === "paid" && (
          <Alert severity="success" sx={{ mt: 1 }}>
            Оплату підтверджено криптографічно верифікованим webhook-сповіщенням!
          </Alert>
        )}

        <Box>
          <Button
            size="small"
            startIcon={<RefreshIcon />}
            onClick={() => onRefresh(order.order_id)}
          >
            Оновити статус
          </Button>
        </Box>
      </Stack>
    </Paper>
  );
}
