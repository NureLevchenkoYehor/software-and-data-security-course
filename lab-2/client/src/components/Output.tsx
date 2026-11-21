import { Box, Paper, Typography } from "@mui/material";
import { ChatCodeBlock } from '@mui/x-chat';

type Props = {
  content: string
  outputVisibility: 'hidden' | 'visible'
}

export default function Output({ content, outputVisibility }: Props) {
  return (
    <Paper elevation={4} sx={{ width: '100%', maxWidth: 1260, p: 4, visibility: outputVisibility }}>
      <Box>
        <ChatCodeBlock language="txt" sx={{ fontWeight: 800 }} >
          {content}
        </ChatCodeBlock>
      </Box>
    </Paper>
  );
}