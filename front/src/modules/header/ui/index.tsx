import { AppBar, Toolbar, Typography } from "@mui/material";
import { observer } from "mobx-react-lite";
import MetaMask from "../components/metamask";

const Header = observer(() => {
  return (
    <AppBar position="static" color="transparent" >
      <Toolbar>
        <Typography
          variant="h5"
          component="div"
          color="#f8f8f8;"
          sx={{ flexGrow: 1 }}
        >
          defi-tigers
        </Typography>

        <MetaMask />
      </Toolbar>
    </AppBar>
  );
});

export default Header;
