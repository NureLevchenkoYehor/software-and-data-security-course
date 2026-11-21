import MainPage from "@/pages/MainPage";
import { HandshakeProvider } from "@/context/HandshakeContext";

export default function App() {
  return (
    <HandshakeProvider>
      <MainPage />
    </HandshakeProvider>
  );
}
