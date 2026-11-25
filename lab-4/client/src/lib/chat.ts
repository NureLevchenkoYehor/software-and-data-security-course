import { WS_URL, decryptJson, encryptJson, isEnvelope, type Envelope } from "@/lib/crypto";

export type ChatMessage = {
  id: number;
  author: string | null; // null for system events (join/leave)
  text: string;
  time: number;
  raw?: Envelope; // the encrypted frame this tab received, for inspection
};

type Handlers = {
  onHistory: (messages: ChatMessage[]) => void;
  onMessage: (message: ChatMessage) => void;
  onUsers: (users: string[]) => void;
  onClose: (reason: string) => void;
};

/// Opens the chat WebSocket. Browsers cannot set headers on a WebSocket, so
/// the session ID is sent as the first message; everything after it is
/// encrypted with the session key.
export function connectChat(sessionId: string, aesKey: CryptoKey, handlers: Handlers) {
  const socket = new WebSocket(WS_URL);

  socket.addEventListener("open", () => {
    socket.send(JSON.stringify({ sessionId }));
  });

  socket.addEventListener("message", async (event) => {
    const envelope: unknown = JSON.parse(String(event.data));
    if (!isEnvelope(envelope)) {
      return;
    }
    const payload = (await decryptJson(aesKey, envelope)) as Record<string, unknown>;
    if (payload.type === "history") {
      handlers.onHistory(payload.messages as ChatMessage[]);
    } else if (payload.type === "message") {
      handlers.onMessage({ ...(payload.message as ChatMessage), raw: envelope });
    } else if (payload.type === "users") {
      handlers.onUsers(payload.users as string[]);
    }
  });

  socket.addEventListener("close", (event) => {
    handlers.onClose(event.reason || "Connection closed.");
  });

  return {
    async send(text: string) {
      socket.send(JSON.stringify(await encryptJson(aesKey, { type: "message", text })));
    },
  };
}
