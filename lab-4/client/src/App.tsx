import { CssBaseline } from "@mui/material";
import MainPage from "@/pages/MainPage";
import { SessionProvider } from "@/context/SessionContext";

export default function App() {
  return (
    <SessionProvider>
      <CssBaseline />
      <MainPage />
    </SessionProvider>
  );
}
