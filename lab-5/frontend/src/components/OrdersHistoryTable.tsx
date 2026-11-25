import {
  Button,
  Card,
  CardHeader,
  Divider,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from "@mui/material";
import RefreshIcon from "@mui/icons-material/Refresh";
import { formatMoney, type OrderRecord } from "../api";
import { OrderStatusChip } from "./OrderStatusChip";

interface OrdersHistoryTableProps {
  orders: OrderRecord[];
  onRefresh: () => void;
}

export function OrdersHistoryTable({
  orders,
  onRefresh,
}: OrdersHistoryTableProps) {
  return (
    <Card>
      <CardHeader
        title="Історія замовлень (In-Memory Store)"
        subheader="Статуси оновлюються виключно серверним Webhook-обробником після перевірки Stripe-Signature"
        action={
          <Button
            size="small"
            startIcon={<RefreshIcon />}
            onClick={onRefresh}
          >
            Оновити
          </Button>
        }
      />
      <Divider />
      <TableContainer>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Order ID</TableCell>
              <TableCell>Опис</TableCell>
              <TableCell>Сума</TableCell>
              <TableCell>PaymentIntent ID</TableCell>
              <TableCell>Статус</TableCell>
              <TableCell>Webhook Event / Примітка</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {orders.length === 0 ? (
              <TableRow>
                <TableCell colSpan={6} align="center">
                  <Typography
                    variant="body2"
                    color="text.secondary"
                    sx={{ py: 2 }}
                  >
                    Замовлень ще немає.
                  </Typography>
                </TableCell>
              </TableRow>
            ) : (
              orders.map((order) => (
                <TableRow key={order.order_id} hover>
                  <TableCell sx={{ fontFamily: "monospace" }}>
                    {order.order_id}
                  </TableCell>
                  <TableCell>{order.description}</TableCell>
                  <TableCell>
                    {formatMoney(order.amount, order.currency)}
                  </TableCell>
                  <TableCell sx={{ fontFamily: "monospace" }}>
                    {order.payment_intent_id ?? "—"}
                  </TableCell>
                  <TableCell>
                    <OrderStatusChip status={order.status} />
                  </TableCell>
                  <TableCell sx={{ fontFamily: "monospace", fontSize: 12 }}>
                    {order.last_event_id
                      ? `${order.last_event_id}${order.failure_reason ? ` (${order.failure_reason})` : ""}`
                      : "Очікується webhook"}
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </TableContainer>
    </Card>
  );
}
