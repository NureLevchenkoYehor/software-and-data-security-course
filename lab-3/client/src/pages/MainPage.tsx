import { Box, Paper, Stack, Tab, Tabs, Typography } from "@mui/material";
import { useState } from "react";
import BitsSelect from "@/components/BitsSelect";
import DigestPanel from "@/components/DigestPanel";
import SignaturePanel from "@/components/SignaturePanel";
import type { Bits } from "@/lib/api";

export default function MainPage() {
  const [tab, setTab] = useState(0);
  const [bits, setBits] = useState<Bits>(8);

  return (
    <Box sx={{ minHeight: "100vh", display: "flex", justifyContent: "center", p: 2 }}>
      <Paper elevation={3} sx={{ p: 3, width: "100%", maxWidth: 720, alignSelf: "flex-start", mt: 6 }}>
        <Stack spacing={2}>
          <Typography variant="h4" sx={{ fontWeight: 800 }}>
            TinyHash
          </Typography>
          <BitsSelect value={bits} onChange={setBits} />
          <Tabs value={tab} onChange={(_, value: number) => setTab(value)}>
            <Tab label="Digest" />
            <Tab label="RSA signature" />
          </Tabs>
          <Box hidden={tab !== 0}>
            <DigestPanel bits={bits} />
          </Box>
          <Box hidden={tab !== 1}>
            <SignaturePanel bits={bits} />
          </Box>
        </Stack>
      </Paper>
    </Box>
  );
}
