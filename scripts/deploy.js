const hre = require("hardhat");

async function main() {
  const decentralizedTaskSystem = await hre.ethers.deployContract(
    "DecentralizedTaskSystem"
  );

  await decentralizedTaskSystem.waitForDeployment();

  console.log(
    `DecentralizedTaskSystem deployed to ${decentralizedTaskSystem.target}`
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
