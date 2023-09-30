import { expect } from "chai";
import { ethers } from "hardhat";

describe("Depositor", async function () {
  const signer = await ethers.provider.getSigner(0);

  it("It should deploy the contract, set the owner and the sponsor", async function () {
    const Depositor = await ethers.getContractFactory("Depositor");
    const depositor = await Depositor.deploy();
    await depositor.deployed();

    expect(await depositor.owner()).to.equal(await signer.getAddress());
    expect(await depositor.sponsor()).to.equal(
      "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"
    );
  });
});
