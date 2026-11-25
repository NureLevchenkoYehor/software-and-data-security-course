export const API_URL = "http://localhost:8000";

export type Bits = 2 | 4 | 8;

export type DigestResult = {
  name: string;
  size: number;
  bits: Bits;
  digest: number;
  binary: string;
  hex: string;
};

export type SignResult = DigestResult & { signature: string };
export type VerifyResult = DigestResult & { valid: boolean };

async function post<T>(path: string, fields: Record<string, string | Blob>): Promise<T> {
  const body = new FormData();
  for (const [key, value] of Object.entries(fields)) {
    body.append(key, value);
  }

  let response: Response;
  try {
    response = await fetch(`${API_URL}${path}`, { method: "POST", body });
  } catch {
    throw new Error("The server is unreachable. Is it running on port 8000?");
  }

  if (!response.ok) {
    const data: unknown = await response.json().catch(() => null);
    const detail =
      typeof data === "object" && data !== null && "detail" in data && typeof data.detail === "string"
        ? data.detail
        : `Request failed (${response.status}).`;
    throw new Error(detail);
  }
  return (await response.json()) as T;
}

export function getDigest(file: File, bits: Bits) {
  return post<DigestResult>("/api/digest", { file, bits: String(bits) });
}

export function signFile(file: File, bits: Bits) {
  return post<SignResult>("/api/sign", { file, bits: String(bits) });
}

export function verifyFile(file: File, signature: string, bits: Bits) {
  return post<VerifyResult>("/api/verify", { file, signature, bits: String(bits) });
}
