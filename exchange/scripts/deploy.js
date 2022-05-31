async function main() {

  const MoonrayExchange = await ethers.getContractFactory("MoonrayExchange");
  const MoonrayExchangeMultiple = await ethers.getContractFactory("MoonrayExchangeMultiple");

  // Start deployment, returning a promise that resolves to a contract object
  console.log("Deployment starting for MoonrayExchange");
  const moonrayExchange = await MoonrayExchange.deploy();
  await moonrayExchange.deployed();
  console.log("MoonrayExchange Contract deployed to address:", moonrayExchange.address);

  console.log("Deployment starting for MoonrayExchangeMultiple");
  const moonrayExchangeMultiple = await MoonrayExchangeMultiple.deploy();
  await moonrayExchangeMultiple.deployed();
  console.log("MoonrayExchangeMultiple Contract deployed to address:", moonrayExchangeMultiple.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
