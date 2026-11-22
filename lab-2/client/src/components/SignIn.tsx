import { Alert, Box, Button, Paper, Stack, Typography } from "@mui/material";
import TextField from "@mui/material/TextField";
import { useState, type FormEvent } from "react";
import { decodeBase64, encodeBase64 } from "@/lib/crypto";
import { useHandshake } from "@/context/HandshakeContext";

type Props = {
  onSuccess: (content: string) => void;
};

type LoginResponse = {
  iv: string;
  ciphertext: string;
};

function isLoginResponse(value: unknown): value is LoginResponse {
  return (
    typeof value === "object" &&
    value !== null &&
    "iv" in value &&
    typeof value.iv === "string" &&
    "ciphertext" in value &&
    typeof value.ciphertext === "string"
  );
}

export default function SignIn({ onSuccess }: Props) {
  const { aesKey, error: handshakeError, isLoading } = useHandshake();
  const [login, setLogin] = useState("");
  const [password, setPassword] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsSubmitting(true);
    setError(null);

    try {
      if (!aesKey) {
        throw new Error("Complete the handshake before signing in.");
      }

      const iv = crypto.getRandomValues(new Uint8Array(12));
      const payload = new TextEncoder().encode(JSON.stringify({ login, password }));
      const ciphertext = await crypto.subtle.encrypt(
        { name: "AES-GCM", iv },
        aesKey,
        payload,
      );
      const response = await fetch("http://localhost:8000/api/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "include",
        body: JSON.stringify({
          iv: encodeBase64(iv),
          ciphertext: encodeBase64(new Uint8Array(ciphertext)),
        }),
      });

      if (!response.ok) {
        setError(
          response.status === 401
            ? "Invalid login or password, or the handshake session has expired."
            : `Request failed (${response.status}).`,
        );
        return;
      }

      const data: unknown = await response.json();
      if (!isLoginResponse(data)) {
        throw new Error("The API returned an invalid login response.");
      }

      const responseIv = decodeBase64(data.iv);
      const responseCiphertext = decodeBase64(data.ciphertext);
      if (responseIv.length !== 12) {
        throw new Error("The API returned an invalid response IV.");
      }

      const plaintext = await crypto.subtle.decrypt(
        {
          name: "AES-GCM",
          iv: responseIv,
        },
        aesKey,
        responseCiphertext,
      );
      onSuccess(new TextDecoder().decode(plaintext));
    } catch (submitError) {
      setError(
        submitError instanceof Error
          ? submitError.message
          : "Could not complete secure sign-in.",
      );
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <Paper elevation={4} sx={{ width: "100%", maxWidth: 420, p: 4 }}>
      <Stack component="form" spacing={2} onSubmit={handleSubmit}>
        <Box>
          <Typography variant="h4" sx={{ fontWeight: 800 }}>
            Get data securely :3
          </Typography>
        </Box>

        {handshakeError && (
          <Alert severity="error">
            Secure sign-in could not be initialized. Reload the page to retry.
          </Alert>
        )}
        {error && <Alert severity="error">{error}</Alert>}

        <TextField
          required
          label="Login"
          value={login}
          onChange={event => {
            setError(null);
            setLogin(event.target.value);
          }}
          autoComplete="username"
        />

        <TextField
          required
          label="Password"
          type="password"
          value={password}
          onChange={event => {
            setError(null);
            setPassword(event.target.value);
          }}
          autoComplete="current-password"
        />

        <Button
          type="submit"
          variant="contained"
          disabled={isSubmitting || isLoading || !aesKey}
        >
          {isSubmitting ? "Signing in..." : "Sign in"}
        </Button>
      </Stack>
    </Paper>
  );
}
