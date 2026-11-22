import { createContext, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import { establishSessionKey } from "@/lib/crypto";

type HandshakeContextValue = {
  aesKey: CryptoKey | null;
  error: string | null;
  isLoading: boolean;
};

/// A React context that provides the AES session key, any handshake error, and 
/// the loading state.
const HandshakeContext = createContext<HandshakeContextValue | undefined>(undefined);

type Props = {
  children: ReactNode;
};

/// A React context provider that establishes a secure session key with the server 
/// and provides it to its children.
export function HandshakeProvider({ children }: Props) {
  const [aesKey, setAesKey] = useState<CryptoKey | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const handshakeStarted = useRef(false);

  useEffect(() => {
    if (handshakeStarted.current) {
      return;
    }
    handshakeStarted.current = true;

    async function initializeSession() {
      try {
        setAesKey(await establishSessionKey());
      } catch (handshakeError) {
        setError(
          handshakeError instanceof Error
            ? handshakeError.message
            : "Could not complete the handshake.",
        );
      } finally {
        setIsLoading(false);
      }
    }

    void initializeSession();
  }, []);

  return (
    <HandshakeContext.Provider value={{ aesKey, error, isLoading }}>
      {children}
    </HandshakeContext.Provider>
  );
}

export function useHandshake() {
  const context = useContext(HandshakeContext);
  if (context === undefined) {
    throw new Error("useHandshake must be used within a HandshakeProvider.");
  }
  return context;
}
