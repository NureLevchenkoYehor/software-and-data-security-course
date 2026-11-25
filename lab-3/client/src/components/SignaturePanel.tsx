import { Alert, Button, Divider, Stack, TextField, Typography } from "@mui/material";
import { useState } from "react";
import DigestCard from "@/components/DigestCard";
import FilePicker from "@/components/FilePicker";
import { signFile, verifyFile, type Bits, type SignResult, type VerifyResult } from "@/lib/api";

function errorMessage(e: unknown) {
  return e instanceof Error ? e.message : String(e);
}

export default function SignaturePanel({ bits }: { bits: Bits }) {
  const [signTarget, setSignTarget] = useState<File | null>(null);
  const [signed, setSigned] = useState<SignResult | null>(null);
  const [signError, setSignError] = useState<string | null>(null);

  const [verifyTarget, setVerifyTarget] = useState<File | null>(null);
  const [signature, setSignature] = useState("");
  const [verified, setVerified] = useState<VerifyResult | null>(null);
  const [verifyError, setVerifyError] = useState<string | null>(null);

  async function sign() {
    if (!signTarget) return;
    setSignError(null);
    try {
      const result = await signFile(signTarget, bits);
      setSigned(result);
      setSignature(result.signature);
    } catch (e) {
      setSigned(null);
      setSignError(errorMessage(e));
    }
  }

  async function verify() {
    if (!verifyTarget || !signature.trim()) return;
    setVerifyError(null);
    try {
      setVerified(await verifyFile(verifyTarget, signature, bits));
    } catch (e) {
      setVerified(null);
      setVerifyError(errorMessage(e));
    }
  }

  return (
    <Stack spacing={2}>
      <Typography variant="h6">Sign</Typography>
      <FilePicker label="File" file={signTarget} onChange={setSignTarget} />
      <Button variant="contained" disabled={!signTarget} onClick={sign}>
        Sign digest
      </Button>
      {signError && <Alert severity="error">{signError}</Alert>}
      {signed && <DigestCard title="Signed digest" result={signed} />}

      <Divider />

      <Typography variant="h6">Verify</Typography>
      <FilePicker label="File" file={verifyTarget} onChange={setVerifyTarget} />
      <TextField
        label="Signature (hex)"
        multiline
        minRows={3}
        value={signature}
        onChange={(event) => setSignature(event.target.value)}
        slotProps={{ htmlInput: { style: { fontFamily: "monospace", wordBreak: "break-all" } } }}
      />
      <Button variant="contained" disabled={!verifyTarget || !signature.trim()} onClick={verify}>
        Verify signature
      </Button>
      {verifyError && <Alert severity="error">{verifyError}</Alert>}
      {verified && (
        <>
          <DigestCard title="Verified digest" result={verified} />
          {verified.valid ? (
            <Alert severity="success">Signature is valid.</Alert>
          ) : (
            <Alert severity="error">Signature is invalid.</Alert>
          )}
        </>
      )}
    </Stack>
  );
}
