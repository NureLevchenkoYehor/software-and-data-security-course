import {
  Alert,
  Button,
  Card,
  CardContent,
  CardHeader,
  CircularProgress,
  Divider,
  FormControl,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
} from "@mui/material";
import ShoppingCartCheckoutIcon from "@mui/icons-material/ShoppingCartCheckout";
import type { Currency, OrderRecord } from "../api";
import { ActiveOrderSummary } from "./ActiveOrderSummary";

export interface ProductPreset {
  id: string;
  label: string;
  description: string;
  amountMajor: string;
  currency: Currency;
}

export const PRODUCT_PRESETS: ProductPreset[] = [
  {
    id: "keyboard",
    label: "Механічна клавіатура Keychron K2 ($49.99)",
    description: "Механічна клавіатура Keychron K2",
    amountMajor: "49.99",
    currency: "usd",
  },
  {
    id: "mouse",
    label: "Бездротова миша Logitech MX ($25.00)",
    description: "Бездротова миша Logitech MX",
    amountMajor: "25.00",
    currency: "usd",
  },
  {
    id: "hub",
    label: "USB-C Хаб 7-в-1 (€19.50)",
    description: "USB-C Хаб 7-в-1",
    amountMajor: "19.50",
    currency: "eur",
  },
  {
    id: "ssd",
    label: "Портативний SSD 1TB (1250.00 UAH)",
    description: "Портативний SSD 1TB",
    amountMajor: "1250.00",
    currency: "uah",
  },
];

interface OrderCreationCardProps {
  selectedPreset: string;
  description: string;
  amountMajor: string;
  currency: Currency;
  createError: string | null;
  creatingIntent: boolean;
  stripeReady: boolean;
  activeOrder: OrderRecord | null;
  onPresetChange: (presetId: string) => void;
  onDescriptionChange: (value: string) => void;
  onAmountChange: (value: string) => void;
  onCurrencyChange: (value: Currency) => void;
  onCreateOrder: () => void;
  onRefreshOrder: (orderId: string) => void;
}

export function OrderCreationCard({
  selectedPreset,
  description,
  amountMajor,
  currency,
  createError,
  creatingIntent,
  stripeReady,
  activeOrder,
  onPresetChange,
  onDescriptionChange,
  onAmountChange,
  onCurrencyChange,
  onCreateOrder,
  onRefreshOrder,
}: OrderCreationCardProps) {
  return (
    <Card sx={{ flex: 1 }}>
      <CardHeader
        title="1. Формування замовлення"
        subheader="Створення замовлення та PaymentIntent на бекенді"
      />
      <Divider />
      <CardContent>
        <Stack spacing={2.5}>
          <FormControl fullWidth size="small">
            <InputLabel id="preset-select-label">Товар / Шаблон</InputLabel>
            <Select
              labelId="preset-select-label"
              label="Товар / Шаблон"
              value={selectedPreset}
              onChange={(e) => onPresetChange(e.target.value)}
            >
              {PRODUCT_PRESETS.map((preset) => (
                <MenuItem key={preset.id} value={preset.id}>
                  {preset.label}
                </MenuItem>
              ))}
            </Select>
          </FormControl>

          <TextField
            label="Опис замовлення"
            value={description}
            onChange={(e) => onDescriptionChange(e.target.value)}
            fullWidth
            size="small"
          />

          <Stack direction="row" spacing={2}>
            <TextField
              label="Сума"
              value={amountMajor}
              onChange={(e) => onAmountChange(e.target.value)}
              type="number"
              slotProps={{ htmlInput: { step: "0.01", min: "1.00" } }}
              fullWidth
              size="small"
            />
            <FormControl sx={{ minWidth: 110 }} size="small">
              <InputLabel id="currency-select-label">Валюта</InputLabel>
              <Select
                labelId="currency-select-label"
                label="Валюта"
                value={currency}
                onChange={(e) => onCurrencyChange(e.target.value as Currency)}
              >
                <MenuItem value="usd">USD</MenuItem>
                <MenuItem value="eur">EUR</MenuItem>
                <MenuItem value="uah">UAH</MenuItem>
              </Select>
            </FormControl>
          </Stack>

          {createError && <Alert severity="error">{createError}</Alert>}

          <Button
            variant="contained"
            size="large"
            startIcon={
              creatingIntent ? (
                <CircularProgress size={18} color="inherit" />
              ) : (
                <ShoppingCartCheckoutIcon />
              )
            }
            disabled={creatingIntent || !stripeReady}
            onClick={onCreateOrder}
          >
            {creatingIntent
              ? "Створення PaymentIntent..."
              : "Створити замовлення та перейти до оплати"}
          </Button>

          {activeOrder && (
            <ActiveOrderSummary
              order={activeOrder}
              onRefresh={onRefreshOrder}
            />
          )}
        </Stack>
      </CardContent>
    </Card>
  );
}
