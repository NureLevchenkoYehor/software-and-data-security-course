import { Alert, Button, Paper, Stack, TextField, Typography } from "@mui/material";
import { useState, type FormEvent } from "react";
import { useSession } from "@/context/SessionContext";
import { API_URL, decryptJson, encryptJson, isEnvelope } from "@/lib/crypto";

type Props = {
  onJoined: (name: string, serverFingerprint: string) => void;
};

type JoinResponse = {
  name: string;
  fingerprint: string;
};

function isJoinResponse(value: unknown): value is JoinResponse {
  return (
    typeof value === "object" &&
    value !== null &&
    "name" in value &&
    typeof value.name === "string" &&
    "fingerprint" in value &&
    typeof value.fingerprint === "string"
  );
}

export default function JoinForm({ onJoined }: Props) {
  const { session, error: handshakeError, isLoading } = useSession();
  const [name, setName] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!session) return;
    setIsSubmitting(true);
    setError(null);

    try {
      const response = await fetch(`${API_URL}/api/join`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-Session-Id": session.sessionId },
        body: JSON.stringify(await encryptJson(session.aesKey, { name })),
      });
      const data: unknown = await response.json();

      if (!response.ok) {
        const detail =
          typeof data === "object" && data !== null && "detail" in data && typeof data.detail === "string"
            ? data.detail
            : `Request failed (${response.status}).`;
        setError(detail);
        return;
      }
      if (!isEnvelope(data)) {
        throw new Error("The API returned an invalid join response.");
      }
      const payload = await decryptJson(session.aesKey, data);
      if (!isJoinResponse(payload)) {
        throw new Error("The API returned an invalid join response.");
      }
      onJoined(payload.name, payload.fingerprint);
    } catch (joinError) {
      setError(joinError instanceof Error ? joinError.message : "Could not join the chat.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <Paper elevation={4} sx={{ width: "100%", p: 4 }}>
      <Stack component="form" spacing={2} onSubmit={handleSubmit}>
        <Typography variant="h4" sx={{ fontWeight: 800 }}>
          Join the chat
        </Typography>

        {handshakeError && (
          <Alert severity="error">
            Secure session could not be initialized: {handshakeError} Reload the page to retry.
          </Alert>
        )}
        {error && <Alert severity="error">{error}</Alert>}

        <TextField
          required
          label="Name"
          value={name}
          slotProps={{ htmlInput: { maxLength: 32 } }}
          onChange={(event) => {
            setError(null);
            setName(event.target.value);
          }}
        />

        <Button type="submit" variant="contained" disabled={isSubmitting || isLoading || !session}>
          {isLoading ? "Establishing secure session..." : isSubmitting ? "Joining..." : "Join"}
        </Button>
      </Stack>
    </Paper>
  );
}
