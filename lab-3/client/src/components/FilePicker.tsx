import UploadFileIcon from "@mui/icons-material/UploadFile";
import { Button, Stack, Typography } from "@mui/material";

type Props = {
  label: string;
  file: File | null;
  onChange: (file: File | null) => void;
};

export default function FilePicker({ label, file, onChange }: Props) {
  return (
    <Stack direction="row" spacing={2} sx={{ alignItems: "center" }}>
      <Button variant="outlined" component="label" startIcon={<UploadFileIcon />} sx={{ flexShrink: 0 }}>
        {label}
        <input
          hidden
          type="file"
          onChange={(event) => {
            onChange(event.target.files?.[0] ?? null);
            event.target.value = "";
          }}
        />
      </Button>
      <Typography variant="body2" color="text.secondary" noWrap>
        {file ? `${file.name} (${file.size} bytes)` : "No file selected"}
      </Typography>
    </Stack>
  );
}
