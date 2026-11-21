import serverPublicKeyPem from "@/secrets/serverPublicKey";

type HandshakeResponse = {
  serverPub: string;
  signature: string;
};

function isHandshakeResponse(value: unknown): value is HandshakeResponse {
  return (
    typeof value === "object" &&
    value !== null &&
    "serverPub" in value &&
    typeof value.serverPub === "string" &&
    "signature" in value &&
    typeof value.signature === "string"
  );
}

export function encodeBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

export function decodeBase64(value: string): Uint8Array {
  const binary = atob(value);
  return Uint8Array.from(binary, character => character.charCodeAt(0));
}

function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const buffer = new ArrayBuffer(bytes.length);
  new Uint8Array(buffer).set(bytes);
  return buffer;
}

function pemToBytes(pem: string): Uint8Array {
  const body = pem
    .replace("-----BEGIN PUBLIC KEY-----", "")
    .replace("-----END PUBLIC KEY-----", "")
    .replace(/\s/g, "");
  return decodeBase64(body);
}

export async function establishSessionKey(): Promise<CryptoKey> {
  const clientKeyPair = await crypto.subtle.generateKey(
    { name: "ECDH", namedCurve: "P-256" },
    false,
    ["deriveBits"],
  );
  const clientPublicBytes = new Uint8Array(
    await crypto.subtle.exportKey("raw", clientKeyPair.publicKey),
  );

  const response = await fetch("http://localhost:8000/api/handshake", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    credentials: "include",
    body: JSON.stringify({ clientPub: encodeBase64(clientPublicBytes) }),
  });
  if (!response.ok) {
    throw new Error(`Handshake failed (${response.status}).`);
  }

  const data: unknown = await response.json();
  if (!isHandshakeResponse(data)) {
    throw new Error("The API returned an invalid handshake response.");
  }

  const serverPublicBytes = decodeBase64(data.serverPub);
  const signature = decodeBase64(data.signature);
  if (clientPublicBytes.length !== 65 || serverPublicBytes.length !== 65) {
    throw new Error("The API returned an invalid P-256 public key.");
  }

  const rsaPublicKey = await crypto.subtle.importKey(
    "spki",
    toArrayBuffer(pemToBytes(serverPublicKeyPem)),
    { name: "RSA-PSS", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const signedBytes = new Uint8Array(serverPublicBytes.length + clientPublicBytes.length);
  signedBytes.set(serverPublicBytes);
  signedBytes.set(clientPublicBytes, serverPublicBytes.length);
  const signatureIsValid = await crypto.subtle.verify(
    { name: "RSA-PSS", saltLength: 32 },
    rsaPublicKey,
    toArrayBuffer(signature),
    toArrayBuffer(signedBytes),
  );
  if (!signatureIsValid) {
    throw new Error("The server handshake signature is invalid.");
  }

  const serverPublicKey = await crypto.subtle.importKey(
    "raw",
    toArrayBuffer(serverPublicBytes),
    { name: "ECDH", namedCurve: "P-256" },
    false,
    [],
  );
  const sharedSecret = await crypto.subtle.deriveBits(
    { name: "ECDH", public: serverPublicKey },
    clientKeyPair.privateKey,
    256,
  );
  const hkdfKey = await crypto.subtle.importKey(
    "raw",
    sharedSecret,
    "HKDF",
    false,
    ["deriveKey"],
  );
  return crypto.subtle.deriveKey(
    {
      name: "HKDF",
      hash: "SHA-256",
      salt: new Uint8Array(32),
      info: new TextEncoder().encode("lab2-login-v1"),
    },
    hkdfKey,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt"],
  );
}
