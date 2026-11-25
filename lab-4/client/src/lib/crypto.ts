import serverPublicKeyPem from "@/secrets/public_key.pem" with { type: "text" };

export const API_URL = "http://localhost:8000";
export const WS_URL = "ws://localhost:8000/api/chat";

type HandshakeResponse = {
  sessionId: string;
  serverPub: string;
  signature: string;
};

type HandshakeResult = {
  sessionId: string;
  clientKeyPair: CryptoKeyPair;
  clientPublicBytes: Uint8Array<ArrayBuffer>;
  serverPublicBytes: Uint8Array<ArrayBuffer>;
  signature: Uint8Array<ArrayBuffer>;
};

/// Everything the UI needs about an established session.
export type Session = {
  sessionId: string;
  aesKey: CryptoKey;
  clientPublicKey: string;
  serverPublicKey: string;
  fingerprint: string;
};

/// An AES-GCM encrypted payload as it travels over the network.
export type Envelope = {
  iv: string;
  ciphertext: string;
};

/// Encodes a Uint8Array into a base64-encoded string.
export function encodeBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

/// Decodes a base64-encoded string into a Uint8Array.
export function decodeBase64(value: string): Uint8Array<ArrayBuffer> {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

/// Establishes a session key with the server using ECDH and HKDF.
export async function establishSession(): Promise<Session> {
  const handshake = await requestHandshake();
  await verifyServerSignature(handshake);
  const sharedSecret = await deriveSharedSecret(handshake);
  return {
    sessionId: handshake.sessionId,
    aesKey: await deriveSessionAesKey(sharedSecret),
    clientPublicKey: encodeBase64(handshake.clientPublicBytes),
    serverPublicKey: encodeBase64(handshake.serverPublicBytes),
    fingerprint: await fingerprintOf(sharedSecret),
  };
}

/// Encrypts a JSON value with the session key.
export async function encryptJson(aesKey: CryptoKey, value: unknown): Promise<Envelope> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const payload = new TextEncoder().encode(JSON.stringify(value));
  const ciphertext = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, aesKey, payload);
  return { iv: encodeBase64(iv), ciphertext: encodeBase64(new Uint8Array(ciphertext)) };
}

/// Decrypts an envelope with the session key and parses the JSON inside.
export async function decryptJson(aesKey: CryptoKey, envelope: Envelope): Promise<unknown> {
  const iv = decodeBase64(envelope.iv);
  if (iv.length !== 12) {
    throw new Error("Invalid IV.");
  }
  const plaintext = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv },
    aesKey,
    decodeBase64(envelope.ciphertext),
  );
  return JSON.parse(new TextDecoder().decode(plaintext));
}

export function isEnvelope(value: unknown): value is Envelope {
  return (
    typeof value === "object" &&
    value !== null &&
    "iv" in value &&
    typeof value.iv === "string" &&
    "ciphertext" in value &&
    typeof value.ciphertext === "string"
  );
}

/// Generates a new ECDH key pair, sends the public key to the server, and
/// receives the session ID, the server's public key and signature.
async function requestHandshake(): Promise<HandshakeResult> {
  const clientKeyPair = await crypto.subtle.generateKey(
    { name: "ECDH", namedCurve: "P-256" },
    false,
    ["deriveBits"],
  );
  const clientPublicBytes = new Uint8Array(
    await crypto.subtle.exportKey("raw", clientKeyPair.publicKey),
  );

  const response = await fetch(`${API_URL}/api/handshake`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
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

  return { sessionId: data.sessionId, clientKeyPair, clientPublicBytes, serverPublicBytes, signature };
}

/// Verifies the server's signature on the handshake response using the known
/// RSA public key.
async function verifyServerSignature(handshake: HandshakeResult): Promise<void> {
  const rsaPublicKey = await crypto.subtle.importKey(
    "spki",
    toArrayBuffer(pemToBytes(serverPublicKeyPem)),
    { name: "RSA-PSS", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const signedBytes = new Uint8Array(
    handshake.serverPublicBytes.length + handshake.clientPublicBytes.length,
  );
  signedBytes.set(handshake.serverPublicBytes);
  signedBytes.set(handshake.clientPublicBytes, handshake.serverPublicBytes.length);

  const signatureIsValid = await crypto.subtle.verify(
    { name: "RSA-PSS", saltLength: 32 },
    rsaPublicKey,
    handshake.signature,
    signedBytes,
  );
  if (!signatureIsValid) {
    throw new Error("The server handshake signature is invalid.");
  }
}

/// Computes the ECDH shared secret from the client's private key and the
/// server's public key.
async function deriveSharedSecret(handshake: HandshakeResult): Promise<ArrayBuffer> {
  const serverPublicKey = await crypto.subtle.importKey(
    "raw",
    handshake.serverPublicBytes,
    { name: "ECDH", namedCurve: "P-256" },
    false,
    [],
  );
  return crypto.subtle.deriveBits(
    { name: "ECDH", public: serverPublicKey },
    handshake.clientKeyPair.privateKey,
    256,
  );
}

/// Derives the AES-GCM session key from the shared secret using HKDF.
async function deriveSessionAesKey(sharedSecret: ArrayBuffer): Promise<CryptoKey> {
  const hkdfKey = await crypto.subtle.importKey("raw", sharedSecret, "HKDF", false, ["deriveKey"]);
  return crypto.subtle.deriveKey(
    {
      name: "HKDF",
      hash: "SHA-256",
      salt: new Uint8Array(32),
      info: new TextEncoder().encode("lab4-chat-v1"),
    },
    hkdfKey,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt", "decrypt"],
  );
}

/// Short public fingerprint of the shared secret (first 8 bytes of SHA-256),
/// used to compare the client's and the server's results.
async function fingerprintOf(sharedSecret: ArrayBuffer): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", sharedSecret));
  return Array.from(digest.slice(0, 8), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function isHandshakeResponse(value: unknown): value is HandshakeResponse {
  return (
    typeof value === "object" &&
    value !== null &&
    "sessionId" in value &&
    typeof value.sessionId === "string" &&
    "serverPub" in value &&
    typeof value.serverPub === "string" &&
    "signature" in value &&
    typeof value.signature === "string"
  );
}

/// Converts a Uint8Array into an ArrayBuffer.
function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const buffer = new ArrayBuffer(bytes.length);
  new Uint8Array(buffer).set(bytes);
  return buffer;
}

/// Converts a PEM-encoded public key into a Uint8Array.
function pemToBytes(pem: string): Uint8Array {
  const body = pem
    .replace("-----BEGIN PUBLIC KEY-----", "")
    .replace("-----END PUBLIC KEY-----", "")
    .replace(/\s/g, "");
  return decodeBase64(body);
}
