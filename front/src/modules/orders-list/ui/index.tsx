import { Contract, ethers } from "ethers";
import { useEffect, useState } from "react";
import walletProvider from "../../../abi/wallet-provider";
import * as stylex from "@stylexjs/stylex";
import { abi, managerAbi } from "../../../abi/abi";
import { CONTRACT_ADDRESS, INONFUNGIBLE_POSITION_MANAGER } from "../../../abi/addresses";
import { Accordion, AccordionDetails, AccordionSummary } from "@mui/material";
import ExpandMoreIcon from "@mui/icons-material/ExpandMore";
import { Button } from "@mui/material";

const styles = stylex.create({
  wrapper: {
    margin: "10px",
  },
  text: {
    fontFamily: `"Roboto","Helvetica","Arial",sans-serif`,
    fontWeight: "500",
    fontSize: "1.2rem",
    lineHeight: "1.2",
    letterSpacing: "0.0075em",
    color: "#f8f8f8",
    margin: "20px 0",
  },
});

interface PositionInfo {
  token0: number;
  token1: number;
  tickLower: number;
  tickUpper: number;
  liquidity: BigInt;
  fee: number;
}

const OrdersList = () => {
  const [position, setPosition] = useState<any[]>([]);
  const [iD, setId] = useState<any[]>([]);

  useEffect(() => {
    (async () => {
      try {
        const signer = await walletProvider.getSigner();

        const provider = new ethers.JsonRpcProvider(
          "https://polygon-mumbai.g.alchemy.com/v2/D2tYfFd1wVX7OQIYW11wx74GyYUGSNpf"
        );

        const nfpmContract = new Contract(
          INONFUNGIBLE_POSITION_MANAGER,
          managerAbi,
          provider
        );

        const numPositions = await nfpmContract.balanceOf(
          "0xAFF32170DA4c3E31A035ca6299D07504Af4E0BA5"
        );

        console.log(numPositions);

        const calls = [];

        for (let i = 0; i < numPositions; i++) {
          calls.push(
            nfpmContract.tokenOfOwnerByIndex(
              "0xAFF32170DA4c3E31A035ca6299D07504Af4E0BA5",
              i
            )
          );
        }

        const positionIds = await Promise.all(calls);

        setId(positionIds);

        const positionCalls = [];

        for (let id of positionIds) {
          positionCalls.push(nfpmContract.positions(id));
        }

        const callResponses = await Promise.all(positionCalls);

        console.log(callResponses);

        const positionInfos = callResponses.map((position) => {
          return {
            token0: position.token0,
            token1: position.token1,
            tickLower: position.tickLower,
            tickUpper: position.tickUpper,
            liquidity: position.liquidity,
            fee: position.fee,
          };
        });
        console.log(positionInfos);
        setPosition(positionInfos);
        console.log(position);
      } catch (error) {
        console.log(error);
      }
    })();
  }, []);

  const deleteOrder =async (tokenID: any | ethers.Overrides, token0: any | ethers.Overrides, token1: any | ethers.Overrides, fee: any | ethers.Overrides) => {
    try{
    const signer = await walletProvider.getSigner();
    const primitivesWithSigner = new Contract(CONTRACT_ADDRESS, abi, signer);
    const tx = await primitivesWithSigner.decreaseLiquidity(
      tokenID, token0, token1, fee
    );
    tx.wait();
    } catch (error) {
      console.log(error);
    }
  };

  if (position.length > 0) {
  return (
    <div {...stylex.props(styles.wrapper)}>
      {position.map((e, index) => ( 
        <Accordion
          key={index}
          sx={{
            background: "transparent",
            border: "1px solid #f8f8f8",
            color: "#f8f8f8",
          }}
          {...stylex.props(styles.text)}
        >
          <AccordionSummary
            expandIcon={<ExpandMoreIcon sx={{ color: "#f8f8f8" }} />}
            aria-controls="panel1bh-content"
            id="panel1bh-header"
          >
            <p> Position ID: {Number(iD[index])} </p>
          </AccordionSummary>

          <AccordionDetails>
            <p>Token1: {e.token0}</p>
            <p>Token2: {e.token1}</p>
            <p>UpperTick: {Number(e.tickUpper)}</p>
            <p>LowerTick: {Number(e.tickLower)}</p>
            <p>Liquidity: {Number(e.liquidity)}</p>
            <Button sx={{ mt: "40px" }} variant="outlined" onClick={() => deleteOrder(iD[index], e.token0, e.token1, e.fee)}>
              Close Position
            </Button>
          </AccordionDetails>
        </Accordion>
      ))}
    </div>
  );} else { return (
    <div>
      <h1 {...stylex.props(styles.text)}>No orders</h1>
    </div>
  )
}
};

export default OrdersList;
