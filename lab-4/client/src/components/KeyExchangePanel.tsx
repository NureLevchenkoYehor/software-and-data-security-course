import { Chip, Paper, Stack, Tooltip, Typography } from "@mui/material";
import { useSession } from "@/context/SessionContext";

type Props = {
  serverFingerprint: string | null;
};

function Field({ label, value }: { label: string; value: string }) {
  return (
    <Stack spacing={0.25}>
      <Typography variant="caption" color="text.secondary">
        {label}
      </Typography>
      <Tooltip title={value}>
        <Typography variant="body2" noWrap sx={{ fontFamily: "monospace" }}>
          {value}
        </Typography>
      </Tooltip>
    </Stack>
  );
}

/// Shows this tab's key exchange: both ECDH public keys, the signature check
/// and the fingerprints of the shared secret computed by each side.
export default function KeyExchangePanel({ serverFingerprint }: Props) {
  const { session, isLoading, error } = useSession();

  return (
    <Paper variant="outlined" sx={{ p: 2 }}>
      <Stack spacing={1.5}>
        <Typography variant="subtitle1" sx={{ fontWeight: 700 }}>
          Key exchange
        </Typography>

        {isLoading && <Chip label="Handshake in progress" />}
        {error && <Chip color="error" label="Handshake failed" />}

        {session && (
          <>
            <Chip color="success" variant="outlined" label="Server RSA-PSS signature verified" />
            <Field label="Client ECDH public key (P-256)" value={session.clientPublicKey} />
            <Field label="Server ECDH public key (P-256)" value={session.serverPublicKey} />
            <Field label="Shared secret fingerprint (client)" value={session.fingerprint} />
            {serverFingerprint && (
              <>
                <Field label="Shared secret fingerprint (server)" value={serverFingerprint} />
                {serverFingerprint === session.fingerprint ? (
                  <Chip color="success" label="Both sides derived the same key" />
                ) : (
                  <Chip color="error" label="Keys differ" />
                )}
              </>
            )}
          </>
        )}
      </Stack>
    </Paper>
  );
}
