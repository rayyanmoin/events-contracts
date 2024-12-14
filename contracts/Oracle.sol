// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";
import "./FullMath.sol";
import "./IOracle.sol";

interface IERC20{
    function decimals() external view returns (uint8);
}

contract Oracle is IOracle {
    using FixedPoint for *;

    address public constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address public constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address public constant ALPHA = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant USDC = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;

    address public constant UNISWAP_V2_FACTORY =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    IUniswapV2Factory uniswapV2Factory;
    mapping(address => uint256) public cummulativeAveragePrice;
    mapping(address => uint256) public cummulativeEthPrice;
    mapping(address => uint32) public tokenToTimestampLast;
    mapping(address => uint256) public cummulativeAveragePriceReserve;
    mapping(address => uint256) public cummulativeEthPriceReserve;
    mapping(address => uint32) public lastTokenTimestamp;
    event AssetValue(uint256, uint256);

    constructor() {
        uniswapV2Factory = IUniswapV2Factory(UNISWAP_V2_FACTORY);
    }

    function setValues(address token) public {
        address pool = uniswapV2Factory.getPair(token, WMATIC);
        if (pool != address(0)) {
            if (WMATIC < token) {
               (
                    cummulativeEthPrice[token],
                    cummulativeAveragePrice[token],
                    tokenToTimestampLast[token]
                ) = UniswapV2OracleLibrary.currentCumulativePrices(
                    address(pool)
                );

                cummulativeAveragePriceReserve[token] = IUniswapV2Pair(pool)
                    .price0CumulativeLast();
                cummulativeEthPrice[token] = IUniswapV2Pair(pool)
                    .price1CumulativeLast();
            } else {
                (
                    cummulativeAveragePrice[token],
                    cummulativeEthPrice[token],
                    tokenToTimestampLast[token]
                ) = UniswapV2OracleLibrary.currentCumulativePrices(
                    address(pool)
                );
                cummulativeAveragePriceReserve[token] = IUniswapV2Pair(pool)
                    .price1CumulativeLast();
                cummulativeEthPrice[token] = IUniswapV2Pair(pool)
                    .price0CumulativeLast();
            }
            tokenToTimestampLast[token] = uint32(block.timestamp);
        }
    }

    // For MATIC chain, eth = matic
    function fetch(address token) external override returns (uint256 price) {
        if (token == USDT || token == USDC) {
            return 1000000;
        }
        if (
            cummulativeAveragePrice[token] == 0 ||
            (uint32(block.timestamp) - lastTokenTimestamp[token]) >= 1 minutes
        ) {
            setValues(token);
        }
        uint256 ethPerUSDT = _getAmounts(USDT);
        emit AssetValue(ethPerUSDT, block.timestamp);
        if (token == WMATIC) {
            price = ethPerUSDT;
            emit AssetValue(price, block.timestamp);
            return price;
        } else {
            uint256 ethPerToken = _getAmounts(token);
            emit AssetValue(ethPerToken, block.timestamp);

            if (ethPerToken == 0 || ethPerUSDT == 0) return 0;

            uint8 decimals = IERC20(token).decimals();
            price = (ethPerUSDT * (10 ** decimals)) / ethPerToken;

            emit AssetValue(price, block.timestamp);
            return price;
        }
    }

    // ALPHAperETH
    function fetchAlphaPrice() external override returns (uint256 price) {
        if (
            cummulativeAveragePrice[ALPHA] == 0 ||
            (uint32(block.timestamp) - lastTokenTimestamp[ALPHA]) >= 3 minutes
        ) {
            setValues(ALPHA);
        }
        uint32 timeElapsed = uint32(
            lastTokenTimestamp[ALPHA] - tokenToTimestampLast[ALPHA]
        );
        price = _calculate(
            cummulativeEthPrice[ALPHA],
            cummulativeAveragePriceReserve[ALPHA],
            timeElapsed,
            ALPHA
        );
        emit AssetValue(price, block.timestamp);
    }

    function _getAmounts(
        address token
    ) internal view returns (uint256 ethPerToken) {
        address poolAddress = uniswapV2Factory.getPair(WMATIC, token);
        if (poolAddress == address(0)) return 0;
        uint32 timeElapsed = uint32(
            lastTokenTimestamp[token] - tokenToTimestampLast[token]
        );
        ethPerToken = _calculate(
            cummulativeAveragePrice[token],
            cummulativeEthPriceReserve[token],
            timeElapsed,
            token
        );
    }

    function _calculate(
        uint256 latestCommulative,
        uint256 oldCommulative,
        uint32 timeElapsed,
        address token
    ) public view returns (uint256 assetValue) {
        FixedPoint.uq112x112 memory priceTemp = FixedPoint.uq112x112(
            uint224((latestCommulative - oldCommulative) / timeElapsed)
        );
        uint8 decimals = IERC20(token).decimals();
        assetValue = priceTemp.mul(10 ** decimals).decode144();
    }
}
