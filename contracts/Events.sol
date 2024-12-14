// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Events is ERC20, Ownable{
    constructor(address initialOwner)
        ERC20("Events", "CC")
        Ownable(initialOwner)
    {}

    // function pause() public onlyOwner {
    //     _pause();
    // }

    // function unpause() public onlyOwner {
    //     _unpause();
    // }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }


}


