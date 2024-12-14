// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

interface IOracle{
    function fetch(address token) external returns (uint256 price);
    function fetchAlphaPrice() external returns (uint256 price);
}