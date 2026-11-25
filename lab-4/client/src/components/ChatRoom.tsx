import SendIcon from "@mui/icons-material/Send";
import { Alert, IconButton, Paper, Stack, TextField, Typography } from "@mui/material";
import { useEffect, useRef, useState, type FormEvent } from "react";
import MessageItem from "@/components/MessageItem";
import { connectChat, type ChatMessage } from "@/lib/chat";
import type { Session } from "@/lib/crypto";

const MAX_MESSAGE_LENGTH = 1000;

type Props = {
  session: Session;
  name: string;
  onUsers: (users: string[]) => void;
};

export default function ChatRoom({ session, name, onUsers }: Props) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [text, setText] = useState("");
  const [closed, setClosed] = useState<string | null>(null);
  const connection = useRef<ReturnType<typeof connectChat> | null>(null);
  const bottom = useRef<HTMLDivElement>(null);

  // Connect once per tab. The server ends the session when its socket closes,
  // so the socket must not be closed by React StrictMode's double mount; it
  // closes together with the tab.
  useEffect(() => {
    if (connection.current) {
      return;
    }
    connection.current = connectChat(session.sessionId, session.aesKey, {
      onHistory: setMessages,
      onMessage: (message) => setMessages((current) => [...current, message]),
      onUsers,
      onClose: setClosed,
    });
  }, [session, onUsers]);

  useEffect(() => {
    bottom.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!text.trim() || !connection.current) return;
    await connection.current.send(text);
    setText("");
  }

  return (
    <Paper elevation={4} sx={{ display: "flex", flexDirection: "column", height: "80vh", p: 2 }}>
      <Typography variant="h5" sx={{ fontWeight: 800, mb: 1 }}>
        Chat
      </Typography>
      <Typography variant="caption" color="text.secondary" sx={{ mb: 1 }}>
        Click a message to see the encrypted frame this tab received.
      </Typography>

      <Stack spacing={1} sx={{ flex: 1, overflowY: "auto", pr: 1 }}>
        {messages.map((message) => (
          <MessageItem key={message.id} message={message} mine={message.author === name} />
        ))}
        <div ref={bottom} />
      </Stack>

      {closed && (
        <Alert severity="warning" sx={{ mt: 1 }}>
          {closed} Reload the page to join again.
        </Alert>
      )}

      <Stack component="form" direction="row" spacing={1} onSubmit={handleSubmit} sx={{ mt: 1 }}>
        <TextField
          fullWidth
          size="small"
          placeholder="Message"
          value={text}
          disabled={closed !== null}
          slotProps={{ htmlInput: { maxLength: MAX_MESSAGE_LENGTH } }}
          onChange={(event) => setText(event.target.value)}
        />
        <IconButton type="submit" color="primary" disabled={closed !== null || !text.trim()}>
          <SendIcon />
        </IconButton>
      </Stack>
    </Paper>
  );
}
