// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IOracle {
    function fetch(address token) external  returns (uint256);
    function fetchAlphaPrice() external  returns (uint256);
}
