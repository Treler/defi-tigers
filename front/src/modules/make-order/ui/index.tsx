import { Button, CircularProgress } from "@mui/material";
import { Contract } from "ethers";
import { ChangeEvent, SyntheticEvent, useEffect, useState } from "react";
import walletProvider from "../../../abi/wallet-provider";
import * as stylex from "@stylexjs/stylex";
import RadioButton from "../../../shared/ui/radio-button";
import Input from "../../../shared/ui/input";
import { abi, tokenAbi } from "../../../abi/abi";
import {
  CONTRACT_ADDRESS,
  TOKEN1_ADDRESS,
  TOKEN2_ADDRESS
  // TOKEN3_ADDRESS,
} from "../../../abi/addresses";
import getPrice from "../../../helpers/get-price";

const styles = stylex.create({
  form: {
    padding: "50px 300px",
    display: "flex",
    flexDirection: "column",
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
  price: {
    fontFamily: `"Roboto","Helvetica","Arial",sans-serif`,
    fontWeight: "500",
    fontSize: "1rem",
    lineHeight: "1.2",
    letterSpacing: "0.0075em",
    color: "#f8f8f8",
  },
  radioWrapper: {
    display: "flex",
  },
});

interface OrderType {
  coin: "matic" | "eth";
  operation: "buy" | "sell";
  fee: 0.01 | 0.05 | 0.3 | 1;
  amount: string;
  strike: string;
}

interface ErrorsType {
  amount?: string;
  strike?: string;
}

interface Props {
  showOrderList: () => void;
}

const MakeOrder = ({ showOrderList }: Props) => {
  const [order, setOrder] = useState<OrderType>({
    coin: "matic",
    operation: "buy",
    fee: 0.3,
    amount: "",
    strike: "",
  });
  const [currentPrice, setCurrentPrice] = useState<number | null>(null);
  const [orderLoading, setOrderLoading] = useState<boolean>(false);
  const [errors, setErrors] = useState<ErrorsType>();

  useEffect(() => {
    (async () => {
      setCurrentPrice(null);
      try {
        const signer = await walletProvider.getSigner();

        const primitivesWithSigner1 = new Contract(
          CONTRACT_ADDRESS,
          abi,
          signer
        );
        const currentSqrtPrice =
          await primitivesWithSigner1.getCurrentSqrtPriceX96(
            order.coin === "eth" ? TOKEN2_ADDRESS : TOKEN1_ADDRESS,
            TOKEN1_ADDRESS,
            Number(order.fee) * 10000
          );
        setCurrentPrice(getPrice(currentSqrtPrice));
      } catch (error) {
        console.log(error);
      }
    })();
  }, [order.operation, order.coin, order.fee]);

  const makeNewOrder = async (e: SyntheticEvent) => {
    e.preventDefault();

    if (order.amount === "" || order.strike === "") {
      if (order.amount === "" && order.strike === "") {
        setErrors({ strike: "Required!", amount: "Required!" });
        return;
      }
      if (order.amount === "") {
        setErrors(
          errors ? { ...errors, amount: "Required!" } : { amount: "Required!" }
        );
        return;
      }
      if (order.strike === "") {
        setErrors(
          errors ? { ...errors, strike: "Required!" } : { strike: "Required!" }
        );
        return;
      }
    }

    // arguments for putOrCall function
    const putOrCall = order.operation === "buy" ? true : false;
    const token1 = order.coin === "eth" ? TOKEN1_ADDRESS : TOKEN2_ADDRESS;
    const token2 = TOKEN2_ADDRESS;
    const amount0ToMint =
      order.operation === "buy"
        ? BigInt(Number(order.amount) * 1e18)
        : BigInt(100);
        console.log(amount0ToMint);
    const amount1ToMint =
      order.operation === "sell"
        ? BigInt(Number(order.amount) * 1e18)
        : BigInt(100);
        console.log(amount1ToMint);
    const poolFee = Number(order.fee) * 10000;
    console.log(poolFee);
    const price = BigInt(Number(order.strike) ** (1 / 2) * (2 ** 96));
    console.log(price);
    setOrderLoading(true);

    try {
      const signer = await walletProvider.getSigner();

      const approveToken1 = new Contract(TOKEN1_ADDRESS, tokenAbi, signer);
      const approveToken2 = new Contract(TOKEN2_ADDRESS, tokenAbi, signer);
      // const approveToken3 = new Contract(TOKEN3_ADDRESS, tokenAbi, signer);

      const primitivesWithSigner = new Contract(CONTRACT_ADDRESS, abi, signer);

      

      if (order.coin === "matic") {
        const approve1 = await approveToken1.approve(
          CONTRACT_ADDRESS,
          BigInt(Number(order.amount) * 1e18)
        );
        approve1.wait();
      }

      if (order.coin === "eth") {
        const approve2 = await approveToken2.approve(
          CONTRACT_ADDRESS,
          BigInt(Number(order.amount) * 1e18)
        );
        approve2.wait();
      }

      const approve3 = await approveToken1.approve(
        CONTRACT_ADDRESS,
        BigInt(Number(order.amount) * 1e18)
      );
      approve3.wait();

      

      const tx = await primitivesWithSigner.putOrCall(
        putOrCall,
        token1,
        token2,
        amount0ToMint,
        amount1ToMint,
        poolFee,
        price
      );
      tx.wait();
      setOrderLoading(false);
      // showOrderList();
    } catch (error) {
      setOrderLoading(false);
      console.log(error);
    }
  };

  return (
    <form {...stylex.props(styles.form)}>
      <h6 {...stylex.props(styles.text)}>Choose coin:</h6>

      <div {...stylex.props(styles.radioWrapper)}>
        <RadioButton
          name="coins-radio-buttons-group"
          id="maticRadio"
          value="matic"
          onChange={() => setOrder({ ...order, coin: "matic" })}
          checked={order.coin === "matic"}
          text="MATIC"
        />
        <RadioButton
          name="coins-radio-buttons-group"
          id="ethRadio"
          value="eth"
          onChange={() => setOrder({ ...order, coin: "eth" })}
          checked={order.coin === "eth"}
          text="WETH"
        />
      </div>

      <h6 {...stylex.props(styles.text)}>Choose operation:</h6>

      <div {...stylex.props(styles.radioWrapper)}>
        <RadioButton
          name="operation-radio-buttons-group"
          id="sellRadio"
          value="sell"
          onChange={() => setOrder({ ...order, operation: "sell" })}
          checked={order.operation === "sell"}
          text="Sell"
        />
        <RadioButton
          name="operation-radio-buttons-group"
          id="buyRadio"
          value="buy"
          onChange={() => setOrder({ ...order, operation: "buy" })}
          checked={order.operation === "buy"}
          text="Buy"
        />
      </div>

      <h6 {...stylex.props(styles.text)}>Choose the fee:</h6>

      <div {...stylex.props(styles.radioWrapper)}>
        <RadioButton
          name="fee-radio-buttons-group"
          id="0.01Radio"
          value="0.01"
          onChange={() => setOrder({ ...order, fee: 0.01 })}
          checked={order.fee === 0.01}
          text="0.01%"
        />
        <RadioButton
          name="fee-radio-buttons-group"
          id="0.05Radio"
          value="0.05"
          onChange={() => setOrder({ ...order, fee: 0.05 })}
          checked={order.fee === 0.05}
          text="0.05%"
        />
        <RadioButton
          name="fee-radio-buttons-group"
          id="0.3Radio"
          value="0.3"
          onChange={() => setOrder({ ...order, fee: 0.3 })}
          checked={order.fee === 0.3}
          text="0.3%"
        />
        <RadioButton
          name="fee-radio-buttons-group"
          id="1Radio"
          value="1"
          onChange={() => setOrder({ ...order, fee: 1 })}
          checked={order.fee === 1}
          text="1%"
        />
      </div>

      <h6 {...stylex.props(styles.text)}>Current price:</h6>
      <p {...stylex.props(styles.price)}>
        {currentPrice !== null ? currentPrice : "Calculating.."}
      </p>

      <h6 {...stylex.props(styles.text)}>Enter amount:</h6>

      <Input
        name="Amount"
        type="text"
        placeholder="Amount"
        value={order.amount}
        error={errors?.amount}
        onChange={(e: ChangeEvent<HTMLInputElement>) => {
          setErrors({});
          const value = e.target.value
            .replace(/[^\d.,]/g, "")
            .replace(/,/g, ".");
          setOrder({ ...order, amount: value });
        }}
      />

      <h6 {...stylex.props(styles.text)}>Enter a strike price:</h6>

      <Input
        name="Strike price"
        type="text"
        placeholder="Strike price"
        value={order.strike}
        error={errors?.strike}
        onChange={(e: ChangeEvent<HTMLInputElement>) => {
          setErrors({});
          const value = e.target.value
            .replace(/[^\d.,]/g, "")
            .replace(/,/g, ".");
          setOrder({ ...order, strike: value });
        }}
      />

      <Button
        sx={{ mt: "40px" }}
        variant="outlined"
        onClick={(e) => makeNewOrder(e)}
        disabled={orderLoading}
      >
        {orderLoading ? <CircularProgress /> : "Make new order"}
      </Button>
    </form>
  );
};

export default MakeOrder;
