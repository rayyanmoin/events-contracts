/** @format */

require("@nomiclabs/hardhat-waffle");
const { version } = require("ethers");
const { PRIVATE_KEY } = require("./env");

module.exports = {
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    aurora: {
      url: "https://testnet.aurora.dev",
      accounts: [PRIVATE_KEY],
    },
  },
};
