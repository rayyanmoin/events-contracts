// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./IEvents.sol";

contract EventTicketing is ERC721, ERC721URIStorage, Ownable {

    IEvents.Ticket[] public tickets;

    uint256 private _nextTokenId;

    string public baseURI;

    constructor(
        address initialOwner
    ) ERC721("Event Ticketing", "ETG") Ownable(initialOwner) {}

    function setBaseURI(string memory baseURI_) external {
        baseURI = baseURI_;
    }

    function _safeMint(address to, string memory uri) internal {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function ticketsOf(address owner) public view returns (uint256[] memory) {
        uint256 _tokenCount = balanceOf(owner);

        if (_tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](_nextTokenId);
            uint256 totalTickets = _nextTokenId;
            uint256 index = 0;

            uint256 ticketId;
            for (ticketId = 1; ticketId <= totalTickets; ticketId++) {
                if (ownerOf(ticketId) == owner) {
                    result[index] = ticketId;
                    index++;
                }
            }
            return result;
        }
    }

    function getTicket(
        uint256 _id
    ) public view returns (IEvents.Ticket memory _ticket) {
        require(
            _id != 0 && _id <= tickets.length,
            "DaoEvents:getTicket: Invalid ID"
        );
        return tickets[_id - 1];
    }

    function uintToString(
        uint _i
    ) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
}