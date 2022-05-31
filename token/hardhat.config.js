/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 require("dotenv").config();
 require("@nomiclabs/hardhat-ethers");
 require("@nomiclabs/hardhat-etherscan");
 const { PRIVATE_KEY, POLYSCAN_API_KEY } = process.env;
 module.exports = {
   defaultNetwork: "mumbai",
   networks: {
    hardhat: {},
    mumbai:{
      url: 'https://rpc-mumbai.maticvigil.com',
      accounts: [`0x${PRIVATE_KEY}`],
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/29f0131a60c4424bb401b8834c78585f`,
      accounts: [`0x${PRIVATE_KEY}`],
    },
   },
   etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: `${POLYSCAN_API_KEY}`
  }
 };
 