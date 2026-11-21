import { Box, Stack } from "@mui/material";
import { useState } from "react";
import Output from "@/components/Output";
import SignIn from "@/components/SignIn";

export default function MainPage() {
  const [content, setContent] = useState("");
  const [outputVisibility, setOutputVisibility] = useState<"hidden" | "visible">("hidden");

  function onSuccess(responseContent: string) {
    setContent(responseContent);
    setOutputVisibility("visible");
  }

  return (
    <Box sx={{ minHeight: "70vh", display: "grid", placeItems: "center" }}>
      <Stack spacing={2} sx={{ justifyContent: "center", alignItems: "center" }}>
        <SignIn onSuccess={onSuccess} />
        <Output content={content} outputVisibility={outputVisibility} />
      </Stack>
    </Box>
  );
}
