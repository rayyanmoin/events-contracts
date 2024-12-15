// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./IOracle.sol";

interface IEvents {
    struct Ticket {
        uint256 seatNo;
        uint256 eventId;
        string boughtLocation;
        string eventLocation;
    }

    struct Event {
        bool oneTimeBuy; // Single purchase restriction
        bool token; // Paid/Free event flag
        bool onsite; // Physical/Virtual designation
        bool isXYZ; // Crypto/USD pricing flag
        address owner; // Event creator
        uint256 time; // Event timestamp
        uint256 totalQuantity; // Total tickets
        uint256 totalQntySold; // Sold tickets
        string name; // Event name
        string topic; // Event category
        string location; // Venue location
        string city; // Event city
        string ipfsHash; // Metadata storage
        bool[] ticketLimited; // Category limits
        uint256[] tktQnty; // Category quantities
        uint256[] prices; // Category prices
        uint256[] tktQntySold; // Category sales
        string[] categories; // Category names
    }

    event TicketPurchased(
        uint256 eventId,
        address buyer,
        uint256 categoryIndex,
        uint256 quantity
    );

    struct SoldTicket {
        bool token;
        uint256 eventId;
        uint256 seatNo;
        address buyer;
        uint256 usdtPrice;
        uint256 alphaPrice;
        uint256 boughtTime;
        uint256 totalTicketsSold;
        uint256 categoryTicketsSold;
        string category;
    }

    event EventCreated(uint256 eventId, string name, address owner, Event);
    event SoldTicketDetails(
        SoldTicket,
        address owner,
        address token,
        bool isAlpha
    );
}