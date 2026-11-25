import { Stack, ToggleButton, ToggleButtonGroup, Typography } from "@mui/material";
import type { Bits } from "@/lib/api";

type Props = {
  value: Bits;
  onChange: (bits: Bits) => void;
};

export default function BitsSelect({ value, onChange }: Props) {
  return (
    <Stack direction="row" spacing={2} sx={{ alignItems: "center" }}>
      <Typography variant="body2">Digest size</Typography>
      <ToggleButtonGroup
        size="small"
        exclusive
        value={value}
        onChange={(_, bits: Bits | null) => bits && onChange(bits)}
      >
        {([2, 4, 8] as const).map((bits) => (
          <ToggleButton key={bits} value={bits}>
            {bits} bits
          </ToggleButton>
        ))}
      </ToggleButtonGroup>
    </Stack>
  );
}
