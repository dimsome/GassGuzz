import express from "express";
import { ethers, Contract } from "ethers";
import cors from "cors";

const app = express();
app.use(cors());
app.use(express.json());

const PORT = 3001;

const sponsorMainAbi = [
  "function executeCall(address to, uint256 value, bytes calldata data)",
];

const DOXXED_PRIVATE_KEY =
  "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";
const provider = new ethers.JsonRpcProvider("http://localhost:8545");
const wallet = new ethers.Wallet(DOXXED_PRIVATE_KEY, provider);

const sponsorMainAddress = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";

const sponsorMain = new ethers.Contract(
  sponsorMainAddress,
  sponsorMainAbi,
  provider
);

const sponsorMainInstance = sponsorMain.connect(wallet) as Contract;

app.post("/tx", async (req, res) => {
  console.log(`Got a request!`);
  const tx = req.body;

  if (!tx.data || !tx.to || !tx.value) {
    res.status(400).send("Invalid data");
    console.log("Got Invalid data");
    return;
  }
  console.log(tx);
  try {
    const txReceipt = await sponsorMainInstance.executeCall([
      tx.to,
      tx.value,
      tx.data,
    ]);
    console.log(txReceipt);
    res.status(200).send(txReceipt);
  } catch (error) {
    console.log(error);
  }
});

app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
