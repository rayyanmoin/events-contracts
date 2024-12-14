const { PRIVATE_KEY } = require("./env.js");
require("@nomiclabs/hardhat-waffle");

module.exports = {
  solidity: "0.8.22",
  networks:{
    mumbai:{
      url:"",
      accounts:[PRIVATE_KEY]
    }
  }
};
