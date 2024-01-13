import { BrowserProvider } from "ethers";

const walletProvider = new BrowserProvider(window.ethereum);

export default walletProvider;
