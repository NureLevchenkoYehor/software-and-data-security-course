import PersonIcon from "@mui/icons-material/Person";
import { List, ListItem, ListItemIcon, ListItemText, Paper, Typography } from "@mui/material";

type Props = {
  users: string[];
  me: string;
};

export default function UsersPanel({ users, me }: Props) {
  return (
    <Paper variant="outlined" sx={{ p: 2 }}>
      <Typography variant="subtitle1" sx={{ fontWeight: 700 }}>
        Online ({users.length})
      </Typography>
      <List dense disablePadding>
        {users.map((user) => (
          <ListItem key={user} disableGutters>
            <ListItemIcon sx={{ minWidth: 32 }}>
              <PersonIcon fontSize="small" color={user === me ? "primary" : "inherit"} />
            </ListItemIcon>
            <ListItemText primary={user === me ? `${user} (you)` : user} />
          </ListItem>
        ))}
      </List>
    </Paper>
  );
}
