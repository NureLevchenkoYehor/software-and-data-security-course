import { Paper, Stack, Typography } from "@mui/material";
import type { DigestResult } from "@/lib/api";

export default function DigestCard({ title, result }: { title: string; result: DigestResult }) {
  return (
    <Paper variant="outlined" sx={{ p: 2, flex: 1, minWidth: 0 }}>
      <Stack spacing={0.5}>
        <Typography variant="overline" color="text.secondary">
          {title}
        </Typography>
        <Typography variant="body2" noWrap>
          {result.name} · {result.size} bytes
        </Typography>
        <Typography variant="h4" sx={{ fontFamily: "monospace", letterSpacing: 4 }}>
          {result.binary}
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ fontFamily: "monospace" }}>
          0x{result.hex} · {result.digest} · {result.bits} bits
        </Typography>
      </Stack>
    </Paper>
  );
}
