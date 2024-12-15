// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.22;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IEvents.sol";

contract Events is ReentrancyGuard, Ownable {
    IOracle public oracle;
    uint256 eventIds;

    mapping(uint256 => Event) public events;
    mapping(address => uint256[]) public ownedEvents;

    modifier goodTime(uint256 _time) {
        require(
            _time > block.timestamp,
            "Events:createEvent: Event time is past"
        );
        _;
    }

    function createEvent(Event memory _event) public goodTime(_event.time) {
        eventIds++;
        require(
            _event.owner == _msgSender(),
            "Events:createEvent: Only owner can create event"
        );
        require(
            _event.totalQuantity == 0,
            "Events:createEvent: Total quantity must be greater than 0"
        );
        require(
            _event.tktQnty.length == _event.categories.length &&
                _event.prices.length == _event.categories.length &&
                _event.tktQntySold.length == _event.categories.length,
            "Events:createEvent: Length of categories, quantities, prices and sold quantities must be equal"
        );
        uint256 _totalTKTQnty;
        for (uint256 i = 0; i < _event.categories.length; i++) {
            require(
                _event.tktQntySold.length == 0,
                "Events:createEvent: Sold quantities must be empty"
            );

            _totalTKTQnty += _event.tktQnty[i];
            if (_event.ticketLimited[i]) {
                require(
                    _event.tktQnty[i] > 0,
                    "Quantity must be greater than 0"
                );
            }
        }

        events[eventIds] = _event;
        ownedEvents[_msgSender()].push(eventIds);
        emit EventCreated(eventIds, _event.name, _event.owner, _event);
    }
    
}
