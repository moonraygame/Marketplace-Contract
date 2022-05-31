const MoonrayExchange = artifacts.require("MoonrayExchange");

module.exports = function (deployer) {
  deployer.deploy(MoonrayExchange);
};
