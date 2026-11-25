import { Box, Stack } from "@mui/material";
import { useState } from "react";
import ChatRoom from "@/components/ChatRoom";
import JoinForm from "@/components/JoinForm";
import KeyExchangePanel from "@/components/KeyExchangePanel";
import UsersPanel from "@/components/UsersPanel";
import { useSession } from "@/context/SessionContext";

export default function MainPage() {
  const { session } = useSession();
  const [name, setName] = useState<string | null>(null);
  const [serverFingerprint, setServerFingerprint] = useState<string | null>(null);
  const [users, setUsers] = useState<string[]>([]);

  function onJoined(joinedName: string, fingerprint: string) {
    setName(joinedName);
    setServerFingerprint(fingerprint);
  }

  return (
    <Box sx={{ display: "flex", justifyContent: "center", p: 2 }}>
      <Stack
        direction={{ xs: "column", md: "row" }}
        spacing={2}
        sx={{ width: "100%", maxWidth: 1100, mt: 4, alignItems: "flex-start" }}
      >
        <Box sx={{ flex: 2, minWidth: 0, width: "100%" }}>
          {session && name ? (
            <ChatRoom session={session} name={name} onUsers={setUsers} />
          ) : (
            <JoinForm onJoined={onJoined} />
          )}
        </Box>
        <Stack spacing={2} sx={{ flex: 1, minWidth: 0, width: "100%" }}>
          {name && <UsersPanel users={users} me={name} />}
          <KeyExchangePanel serverFingerprint={serverFingerprint} />
        </Stack>
      </Stack>
    </Box>
  );
}
