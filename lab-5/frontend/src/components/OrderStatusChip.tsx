import { Chip } from "@mui/material";
import type { OrderStatus } from "../api";

interface OrderStatusChipProps {
  status: OrderStatus;
}

const STATUS_CONFIG: Record<
  OrderStatus,
  { label: string; color: "warning" | "success" | "error" }
> = {
  pending: { label: "Очікує оплати (pending)", color: "warning" },
  paid: { label: "Оплачено (paid)", color: "success" },
  failed: { label: "Відхилено (failed)", color: "error" },
};

export function OrderStatusChip({ status }: OrderStatusChipProps) {
  const { label, color } = STATUS_CONFIG[status];
  return <Chip size="small" label={label} color={color} />;
}
