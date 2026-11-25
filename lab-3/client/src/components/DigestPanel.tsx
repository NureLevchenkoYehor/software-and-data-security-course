import { Alert, Button, Stack, TextField } from "@mui/material";
import { useState } from "react";
import DigestCard from "@/components/DigestCard";
import FilePicker from "@/components/FilePicker";
import { getDigest, type Bits, type DigestResult } from "@/lib/api";

type Results = { first: DigestResult; second: DigestResult | null; expected: string };

function normalizeExpected(value: string, bits: Bits): number | null {
  const clean = value.trim().toLowerCase();
  if (!clean) return null;
  const parsed = clean.startsWith("0x") ? parseInt(clean.slice(2), 16) : parseInt(clean, 2);
  if (Number.isNaN(parsed) || parsed >= 2 ** bits) return Number.NaN;
  return parsed;
}

export default function DigestPanel({ bits }: { bits: Bits }) {
  const [first, setFirst] = useState<File | null>(null);
  const [second, setSecond] = useState<File | null>(null);
  const [expected, setExpected] = useState("");
  const [results, setResults] = useState<Results | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function compute() {
    if (!first) return;
    setLoading(true);
    setError(null);
    try {
      const [a, b] = await Promise.all([getDigest(first, bits), second ? getDigest(second, bits) : null]);
      setResults({ first: a, second: b, expected });
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
      setResults(null);
    } finally {
      setLoading(false);
    }
  }

  const expectedValue = results ? normalizeExpected(results.expected, results.first.bits) : null;

  return (
    <Stack spacing={2}>
      <FilePicker label="File" file={first} onChange={setFirst} />
      <FilePicker label="Compare with" file={second} onChange={setSecond} />
      <TextField
        size="small"
        label="Expected digest (optional)"
        placeholder="binary, e.g. 00011011, or hex, e.g. 0x1b"
        value={expected}
        onChange={(event) => setExpected(event.target.value)}
      />
      <Button variant="contained" disabled={!first || loading} onClick={compute}>
        Compute digest
      </Button>

      {error && <Alert severity="error">{error}</Alert>}

      {results && (
        <>
          <Stack direction={{ xs: "column", sm: "row" }} spacing={2}>
            <DigestCard title="File" result={results.first} />
            {results.second && <DigestCard title="Compare with" result={results.second} />}
          </Stack>
          {results.second &&
            (results.first.digest === results.second.digest ? (
              <Alert severity="success">Digests match.</Alert>
            ) : (
              <Alert severity="warning">Digests differ.</Alert>
            ))}
          {expectedValue !== null &&
            (Number.isNaN(expectedValue) ? (
              <Alert severity="error">Expected digest is not a valid {results.first.bits}-bit value.</Alert>
            ) : expectedValue === results.first.digest ? (
              <Alert severity="success">Digest matches the expected value: integrity confirmed.</Alert>
            ) : (
              <Alert severity="error">Digest does not match the expected value: integrity violated.</Alert>
            ))}
        </>
      )}
    </Stack>
  );
}
