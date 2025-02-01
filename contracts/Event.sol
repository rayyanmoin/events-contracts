//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.22;

import "./IEvents.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./EventTicket.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    function decimals() external view returns (uint8);
}

contract Event is IEvents, ReentrancyGuard, EventTicket {
    IOracle public oracle;
    address public alphaAddress;
    address private adminAddress;

    mapping(uint256 => Event) public events;
    mapping(address => uint256[]) public ownedEvents;
    mapping(address => mapping(uint256 => bool)) public ticketBought; // Mapping from address to event ID to bought or not
    mapping(uint256 => uint256) public eventRevenue;
    mapping(uint8 => WhiteListedToken) public whiteListedTokens;
    uint8 public tokensLength;
    uint256 public eventId;

    constructor(address initialOwner) EventTicket(initialOwner) {
        adminAddress = initialOwner;
    }

    modifier onlyEventOwner(uint256 _eventId) {
        require(events[_eventId].owner == msg.sender, "Not the event owner");
        _;
    }

    modifier goodTime(uint256 _time) {
        require(_time > block.timestamp, "Invalid time");
        _;
    }

    modifier eventExists(uint256 _eventId) {
        require(_eventId <= eventId, "Event does not exist");
        _;
    }

    function createEvent(Event memory _event) public goodTime(_event.time) {
        eventId++;
        require(_event.owner == _msgSender(), "Not the event owner");
        require(_event.totalQntySold == 0, "Event already created");
        require(
            _event.categories.length == _event.tktQnty.length &&
                _event.categories.length == _event.prices.length &&
                _event.categories.length == _event.tktQntySold.length,
            "Invalid categories"
        );

        uint256 _totalTktQnty;
        for (uint256 index = 0; index < _event.categories.length; index++) {
            require(
                _event.tktQntySold[index] == 0,
                "Category quantity sold must be zero"
            );
            _totalTktQnty = _totalTktQnty + _event.tktQnty[index];
            if (_event.ticketLimited[index] == false) {
                require(
                    _event.tktQnty[index] == 0,
                    "Ticket quantity must be zero"
                );
            }
        }
        require(_event.totalQuantity == _totalTktQnty, "Invalid quantity");
        events[eventId] = _event;
        ownedEvents[msg.sender].push(eventId);
        emit EventCreated(eventId, msg.sender, _event);
    }

    function buyTicket(
        BuyTickets memory _buyTicket,
        address token
    )
        public
        payable
        eventExists(_buyTicket.eventId)
        goodTime(events[_buyTicket.eventId].time)
    {
        if (token == address(0) && msg.value > 0) {
            if (token != address(0)) {
                require(
                    isWhiteListed(token),
                    "Token is not whitelisted for payment"
                );
            } else {
                require(msg.value > 0, "Invalid payment");
            }
        }

        uint256 _ticketCategoryIndex = _buyTicket.categoryIndex;
        uint256 _eventId = _buyTicket.eventId;
        uint256 _msgValue = msg.value;
        uint256 tokenId = nextTokenId + 1;

        Event storage _event = events[_eventId];
        uint256 _usdtPrice;
        uint256 _alphaPrice;

        if (!_event.token) {
            _usdtPrice = 0;
            _alphaPrice = 0;
        } else {
            if (token == address(0) && _msgValue > 0) {
                _usdtPrice = _event.prices[_ticketCategoryIndex];
                (_alphaPrice, _msgValue) = updateMsgValue(
                    _alphaPrice,
                    _msgValue
                );
            } else if (_event.isAlpha) {
                _usdtPrice = 0;
                _alphaPrice = _event.prices[_ticketCategoryIndex];
            } else {
                _usdtPrice = _event.prices[_ticketCategoryIndex];
                _alphaPrice = (_usdtPrice * oracle.fetch(token)) / 1e18;
            }
        }

        if (_event.ticketLimited[_ticketCategoryIndex]) {
            require(
                _event.totalQuantity > _event.totalQntySold &&
                    _event.tktQnty[_ticketCategoryIndex] >
                    _event.tktQntySold[_ticketCategoryIndex],
                "Category sold out"
            );
        }

        if (_event.oneTimeBuy) {
            require(
                !ticketBought[msg.sender][_eventId],
                "One time buy event already sold"
            );
            ticketBought[msg.sender][_eventId] = true;
        }

        _buyTicketInternal(_buyTicket, _event, _alphaPrice, tokenId, token);

        if (token != alphaAddress && _event.token == true) {
            uint256 percentToDeduct = 0;
            uint8 decimals = token != address(0)
                ? 18
                : IERC20(token).decimals();
            percentToDeduct =
                (_alphaPrice * ((2 * 10 ** decimals) / 10 ** 2)) /
                10 ** decimals;
            if (token == address(0) && _msgValue > 0) {
                require(
                    _msgValue >= percentToDeduct,
                    "Amount to be paid is insufficient"
                );
                _msgValue -= percentToDeduct;
            }
            sendAmount(_event.token, adminAddress, percentToDeduct, token);

            uint256 _categoryTKTSold = _event.tktQntySold[_ticketCategoryIndex];
            emit SoldTicketDetails(
                SoldTicket(
                    _event.token,
                    _eventId,
                    tokenId,
                    _msgSender(),
                    _usdtPrice,
                    _alphaPrice,
                    block.timestamp,
                    _event.totalQntySold,
                    _categoryTKTSold,
                    _event.categories[_ticketCategoryIndex]
                ),
                msg.sender,
                token,
                _event.isAlpha
            );
        }
    }

    function _buyTicketInternal(
        BuyTickets memory _buyTicket,
        Event storage _event,
        uint256 _alphaPrice,
        uint256 _ticketId,
        address token
    ) internal nonReentrant {
        eventRevenue[_buyTicket.eventId] += _alphaPrice;
        events[_buyTicket.eventId].totalQntySold++;
        events[_buyTicket.eventId].tktQntySold[_buyTicket.categoryIndex]++;
        tickets.push(
            Ticket({
                seatNo: _ticketId,
                eventId: _buyTicket.eventId,
                boughtLocation: _buyTicket.boughtLocation,
                eventLocation: _event.location
            })
        );

        sendAmount(_event.token, _event.owner, _alphaPrice, token);
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        _event.name,
                        '", ',
                        '"description": "',
                        string.concat(
                            _event.location,
                            " - ",
                            _event.categories[_buyTicket.categoryIndex]
                        ),
                        '", ',
                        '"image": "',
                        _event.ipfsHash,
                        '"}'
                    )
                )
            )
        );
        string memory finalTokenUri = string(
            abi.encodePacked("data:application/json;base64,", json)
        );
        _safeMint(_msgSender(), finalTokenUri);
    }

    function sendAmount(
        bool isPaid,
        address to,
        uint256 amount,
        address token
    ) internal {
        if (isPaid) {
            if (token == address(0)) {
                require(msg.value >= amount, "Insufficient payment");
                (bool success, ) = to.call{value: amount}("");
                require(success, "Transfer failed");
            } else {
                IERC20(token).transferFrom(_msgSender(), to, amount);
            }
        }
    }

    function updateMsgValue(
        uint256 _alphaPrice,
        uint256 _msgValue
    ) internal pure returns (uint256, uint256) {
        require(_msgValue > _alphaPrice, "Amount to be paid is insufficient");

        uint256 _98percent = (_alphaPrice * 98) / 100;
        _alphaPrice = _98percent;
        _msgValue -= _98percent;
        return (_alphaPrice, _msgValue);
    }

    function addtoWhiteList(
        WhiteListedToken memory _tokenDetails
    ) public onlyOwner {
        (WhiteListedToken memory tokenDetails, uint8 index) = getTokenByAddress(
            _tokenDetails.tokenAddress
        );
        if (tokenDetails.tokenAddress == address(0)) {
            tokensLength += 1;
            whiteListedTokens[tokensLength] = _tokenDetails;
        } else whiteListedTokens[index] = _tokenDetails;
    }
    //function to check if token is whiteListed or not
    function isWhiteListed(address _tokenAddress) internal view returns (bool) {
        (WhiteListedToken memory tokenDetails, ) = getTokenByAddress(
            _tokenAddress
        );
        return tokenDetails.tokenAddress != address(0);
    }

    function getTokenByAddress(
        address _token
    ) public view returns (WhiteListedToken memory tokenDetails, uint8 index) {
        require(_token != address(0), "Invalid token address.");
        for (uint8 i = 1; i < tokensLength + 1; i++) {
            if (whiteListedTokens[i].tokenAddress == _token) {
                return (whiteListedTokens[i], i);
            }
        }
    }

    function getWhiteListedTokensList()
        external
        view
        returns (WhiteListedToken[] memory)
    {
        WhiteListedToken[]
            memory _whiteListedTokensList = new WhiteListedToken[](
                tokensLength
            );
        //loop over whiteList and add to array
        for (uint8 i = 1; i < tokensLength + 1; i++) {
            _whiteListedTokensList[i - 1] = whiteListedTokens[i];
        }
        return _whiteListedTokensList;
    }
}