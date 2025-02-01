// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Alpha is ERC20, ERC20Pausable, Ownable {
    constructor(
        address initialOwner
    ) ERC20("Alpha", "ALPHA") Ownable(initialOwner) {
        admins[initialOwner] = true;
    }

    mapping(address => bool) private admins;

    modifier onlyAdmin() {
        require(admins[msg.sender]);
        _;
    }

    function setOnlyAdmin(address _onlyAdmin) public onlyOwner {
        admins[_onlyAdmin] = true;
    }

    function pause() public onlyAdmin {
        _pause();
    }

    function unpause() public onlyAdmin {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyAdmin {
        _mint(to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }
}