import { useEffect, useState } from "react";
import { useStores } from "../../../../app/root-store-context";
import {
  Alert,
  Box,
  Button,
  IconButton,
  Menu,
  MenuItem,
  Tooltip,
  Typography,
} from "@mui/material";
import { MetaMaskAvatar } from "react-metamask-avatar";

const MetaMask = () => {
  const { user } = useStores();

  const [walletAddress, setWalletAddress] = useState<string | null>(
    user.address
  );
  const [alert, setAlert] = useState<boolean>(false);
  const [error, setError] = useState<boolean>(false);
  const [anchorElUser, setAnchorElUser] = useState<null | HTMLElement>(null);

  const handleOpenUserMenu = (event: React.MouseEvent<HTMLElement>) => {
    setAnchorElUser(event.currentTarget);
  };

  const handleCloseUserMenu = () => {
    setAnchorElUser(null);
  };

  const connectWallet = async () => {
    if (typeof window != "undefined" && typeof window.ethereum != "undefined") {
      try {
        /* MetaMask is installed */
        const accounts: string[] = await window.ethereum.request({
          method: "eth_requestAccounts",
        });
        setWalletAddress(accounts[0]);
        user.setUser(accounts[0]);
      } catch (error) {
        setError(true);
      }

      return;
    }
    /* MetaMask is not installed */
    setAlert(true);
  };

  const deleteUser = () => {
    handleCloseUserMenu();
    setWalletAddress(null);
    user.deleteUser();
  };

  useEffect(() => {
    const getCurrentWalletConnected = async () => {
      if (
        typeof window != "undefined" &&
        typeof window.ethereum != "undefined"
      ) {
        try {
          /* MetaMask is installed */
          const accounts = await window.ethereum.request({
            method: "eth_accounts",
          });
          if (accounts.length > 0) {
            setWalletAddress(accounts[0]);
            user.setUser(accounts[0]);
          } else {
            setAlert(true);
          }
        } catch (err) {
          setError(true);
        }
      } else {
        /* MetaMask is not installed */
        setAlert(true);
      }
    };

    const addWalletListener = async () => {
      if (
        typeof window != "undefined" &&
        typeof window.ethereum != "undefined"
      ) {
        window.ethereum.on("accountsChanged", (accounts: string[]) => {
          setWalletAddress(accounts[0]);
          user.setUser(accounts[0]);
        });
      } else {
        /* MetaMask is not installed */
        setAlert(true);
      }
    };

    getCurrentWalletConnected();
    addWalletListener();
  }, [user]);

  return (
    <>
      {walletAddress ? (
        <Box sx={{ flexGrow: 0}}>
          <Tooltip title="Open settings">
            <Box>
              <IconButton onClick={handleOpenUserMenu} sx={{ p: 0 }}>
                <MetaMaskAvatar address={walletAddress} size={36} />
                <Typography
                  variant="h6"
                  component="div"
                  color="#f8f8f8;"
                  sx={{ flexGrow: 1, marginLeft: "10px" }}
                >
                  {`${walletAddress.substring(
                    0,
                    6
                  )}...${walletAddress.substring(38)}`}
                </Typography>
              </IconButton>
            </Box>
          </Tooltip>
          <Menu
            sx={{ mt: "40px" }}
            id="menu-appbar"
            anchorEl={anchorElUser}
            anchorOrigin={{
              vertical: "top",
              horizontal: "right",
            }}
            keepMounted
            transformOrigin={{
              vertical: "top",
              horizontal: "right",
            }}
            open={Boolean(anchorElUser)}
            onClose={handleCloseUserMenu}
          >
            <MenuItem onClick={deleteUser}>
              <Typography textAlign="center">log out</Typography>
            </MenuItem>
          </Menu>
        </Box>
      ) : (
        <Button variant="outlined" onClick={connectWallet}>
          Connect MetaMask
        </Button>
      )}

      {alert && (
        <Alert
          severity="warning"
          onClose={() => setAlert(false)}
          sx={{ position: "absolute", right: "25px", top: "70px" }}
        >
          You need to install or connect in MetaMask
        </Alert>
      )}

      {error && (
        <Alert
          severity="error"
          onClose={() => setError(false)}
          sx={{ position: "absolute", right: "25px", top: "70px" }}
        >
          You are didn`t connect in MetaMask
        </Alert>
      )}
    </>
  );
};

export default MetaMask;
