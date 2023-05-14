const path = require("path");
const fs = require("fs");

async function main() {
  // ethers is available in the global scope
  const worldIDAddress = await fetch('https://developer.worldcoin.org/api/v1/contracts')
    .then(res => res.json())
    .then(res => res.find(({ key }) => key === 'staging.semaphore.wld.eth').value);

  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );
  const CM = await ethers.getContractFactory("Openions");
  const cm = await CM.deploy(worldIDAddress);
  await cm.deployed();
  console.log(cm);
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
  const CMArtifact = artifacts.readArtifactSync("Openions");
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