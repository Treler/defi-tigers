import { Box, Tab, Tabs } from "@mui/material";
import { SyntheticEvent, useState } from "react";
import { useStores } from "../app/root-store-context";
import { observer } from "mobx-react-lite";
import { MakeOrder } from "../modules/make-order";
import { OrdersList } from "../modules/orders-list";
import * as stylex from "@stylexjs/stylex";

const styles = stylex.create({
  pageWrapper: {
    width: "100%",
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    marginTop: "50px",
  },
  alertMsg: {
    fontFamily: `"Roboto","Helvetica","Arial",sans-serif`,
    textAlign: "center",
    fontWeight: "500",
    fontSize: "1.25rem",
    lineHeight: "1.6",
    letterSpacing: "0.0075em",
    color: "#f8f8f8",
  },
});

const MainPage = observer(() => {
  const { user } = useStores();

  const [value, setValue] = useState<0 | 1>(0);

  const handleChange = (e: SyntheticEvent, newValue: 0 | 1) => {
    e.preventDefault();
    setValue(newValue);
  };

  return (
    <div {...stylex.props(styles.pageWrapper)}>
      {!user.address ? (
        <h6 {...stylex.props(styles.alertMsg)}>
          You need to connect your MetaMask
        </h6>
      ) : (
        <>
          <Box sx={{ width: "1000px", bgcolor: "#010409" }}>
            <Tabs value={value} onChange={handleChange} centered>
              <Tab label="Make new order" sx={{ color: "#1976d2" }} />
              <Tab label="My active orders list" sx={{ color: "#1976d2" }} />
            </Tabs>
          </Box>
          <Box
            sx={{
              width: "1000px",
              boxShadow:
                "0px 2px 4px -1px rgba(0, 0, 0, 0.2),0px 4px 5px 0px rgba(0, 0, 0, 0.14), 0px 1px 10px 0px rgba(0, 0, 0, 0.12);",
              display: "flex",
              flexDirection: "column",
            }}
          >
            {value === 0 ? (
              <MakeOrder showOrderList={() => setValue(1)} />
            ) : (
              <OrdersList />
            )}
          </Box>
        </>
      )}
    </div>
  );
});

export default MainPage;
