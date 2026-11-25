import { createContext, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import { establishSession, type Session } from "@/lib/crypto";

type SessionContextValue = {
  session: Session | null;
  error: string | null;
  isLoading: boolean;
};

/// A React context that provides this tab's session (ID, AES key and handshake
/// details), any handshake error, and the loading state.
const SessionContext = createContext<SessionContextValue | undefined>(undefined);

type Props = {
  children: ReactNode;
};

/// Establishes a session with the server once per tab. The session lives only
/// in memory, so every tab gets its own session ID and key.
export function SessionProvider({ children }: Props) {
  const [session, setSession] = useState<Session | null>(null);
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
        setSession(await establishSession());
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
    <SessionContext.Provider value={{ session, error, isLoading }}>
      {children}
    </SessionContext.Provider>
  );
}

export function useSession() {
  const context = useContext(SessionContext);
  if (context === undefined) {
    throw new Error("useSession must be used within a SessionProvider.");
  }
  return context;
}
