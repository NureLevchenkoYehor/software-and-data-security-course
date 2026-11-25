import { Box, Collapse, Paper, Stack, Typography } from "@mui/material";
import { useState } from "react";
import type { ChatMessage } from "@/lib/chat";

type Props = {
  message: ChatMessage;
  mine: boolean;
};

function formatTime(seconds: number) {
  return new Date(seconds * 1000).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

/// A chat message. Clicking it shows the encrypted frame this tab received.
export default function MessageItem({ message, mine }: Props) {
  const [showRaw, setShowRaw] = useState(false);

  if (message.author === null) {
    return (
      <Typography variant="caption" color="text.secondary" sx={{ textAlign: "center", py: 0.5 }}>
        {message.text} · {formatTime(message.time)}
      </Typography>
    );
  }

  return (
    <Box sx={{ display: "flex", justifyContent: mine ? "flex-end" : "flex-start" }}>
      <Paper
        elevation={0}
        onClick={() => setShowRaw((value) => !value)}
        sx={{
          px: 1.5,
          py: 1,
          maxWidth: "75%",
          minWidth: 0,
          cursor: message.raw ? "pointer" : "default",
          bgcolor: mine ? "primary.main" : "grey.100",
          color: mine ? "primary.contrastText" : "text.primary",
        }}
      >
        <Stack spacing={0.25}>
          <Typography variant="caption" sx={{ fontWeight: 700, opacity: 0.85 }}>
            {message.author} · {formatTime(message.time)}
          </Typography>
          <Typography variant="body1" sx={{ whiteSpace: "pre-wrap", wordBreak: "break-word" }}>
            {message.text}
          </Typography>
          {message.raw && (
            <Collapse in={showRaw}>
              <Typography
                variant="caption"
                component="div"
                sx={{ fontFamily: "monospace", wordBreak: "break-all", opacity: 0.85, mt: 0.5 }}
              >
                iv: {message.raw.iv}
                <br />
                ciphertext: {message.raw.ciphertext}
              </Typography>
            </Collapse>
          )}
        </Stack>
      </Paper>
    </Box>
  );
}
