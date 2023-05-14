// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const path = require("path");
const fs = require("fs");

async function main() {
  // ethers is available in the global scope
  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );
  const CM = await ethers.getContractFactory("AnonyPoll");
  const cm = await CM.deploy(deployer.address);
  await cm.deployed();
  saveFrontendFiles(cm);
}
// we add this part to save artifacts and address
function saveFrontendFiles(cm) {
  const contractsDir = path.join(__dirname, "/../frontend/src/contracts");
  if (!fs.existsSync(contractsDir)) {
    fs.mkdirSync(contractsDir);
  }
  fs.writeFileSync(
    contractsDir + "/contract-address.json",
    JSON.stringify({ CM: cm.address }, null, 2)
  );
  // `artifacts` is a helper property provided by Hardhat to read artifacts
  const CMArtifact = artifacts.readArtifactSync("AnonyPoll");
  fs.writeFileSync(
    contractsDir + "/CM.json",
    JSON.stringify(CMArtifact, null, 2)
  );
}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });