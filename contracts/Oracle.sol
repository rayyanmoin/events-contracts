// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";
import "./FullMath.sol";
import "./IOracle.sol";
interface IERC20 {
    function decimals() external view returns (uint8);
}
contract Oracle is IOracle {
    using FixedPoint for *;

    address public constant WMATIC = address(0);
    address public constant ALPHA = address(0);
    address public constant WETH = address(0);
    address public constant USDC = address(0);
    address public constant USDT = address(0);

    address public constant UNISWAP_V2_FACTORY = address(0);

    IUniswapV2Factory factoryInterface;
    mapping(address => uint256) public commulativeAveragePrice;
    mapping(address => uint256) public commulativeETHPrice;
    mapping(address => uint32) public tokenToTimestampLast;
    mapping(address => uint256) public commulativeAveragePriceReserve;
    mapping(address => uint256) public commulativeETHPriceReserve;
    mapping(address => uint32) public lastTokenTimestamp;

    event AssetValue(uint256, uint256);

    constructor() {
        factoryInterface = IUniswapV2Factory(UNISWAP_V2_FACTORY);
        //setValues(USDT);
    }

    function setValues(address token) public {
        address pool = factoryInterface.getPair(WMATIC, token);
        if (pool != address(0)) {
            if (WMATIC < token) {
                (
                    commulativeETHPrice[token],
                    commulativeAveragePrice[token],
                    tokenToTimestampLast[token]
                ) = UniswapV2OracleLibrary.currentCumulativePrices(
                    address(pool)
                );
            } else {
                (
                    commulativeAveragePrice[token],
                    commulativeETHPrice[token],
                    tokenToTimestampLast[token]
                ) = UniswapV2OracleLibrary.currentCumulativePrices(
                    address(pool)
                );
            }

            lastTokenTimestamp[token] = uint32(block.timestamp);
        }
    }

    function fetch(address token) external override returns (uint256 price) {
        if (token == USDT || token == USDC) {
            return 1.000000;
        }

        if (
            commulativeAveragePrice[token] == 0 ||
            ((uint256(block.timestamp) - uint256(lastTokenTimestamp[token]))) >=
            1 minutes
        ) {
            setValues(token);
        }

        uint256 ethPerUSDT = _getAmount(USDT);
        emit AssetValue(ethPerUSDT, block.timestamp);

        if (token == WMATIC) {
            price = ethPerUSDT;
            emit AssetValue(ethPerUSDT, block.timestamp);
            emit AssetValue(price, block.timestamp);
            return price;
        } else {
            uint256 ethPerToken = _getAmount(token);
            emit AssetValue(ethPerToken, block.timestamp);
            if (ethPerToken == 0 || ethPerUSDT == 0) {
                return 0;
            }
            uint8 decimals = IERC20(token).decimals();
            price = (ethPerUSDT * (10 ** decimals)) / ethPerToken;
            emit AssetValue(price, block.timestamp);
            return price;
        }
    }

    function fetchAlphaPrice() external override returns (uint256 price) {
        if (
            commulativeAveragePrice[ALPHA] == 0 ||
            ((uint256(block.timestamp) - uint256(lastTokenTimestamp[ALPHA]))) >=
            3 minutes
        ) {
            setValues(ALPHA);
        }

        uint32 timeElapsed = uint32(
            (uint256(lastTokenTimestamp[ALPHA]) -
                uint256(tokenToTimestampLast[ALPHA]))
        );

        price = _calculate(
            commulativeETHPrice[ALPHA],
            commulativeAveragePrice[ALPHA],
            timeElapsed,
            ALPHA
        );
        emit AssetValue(price, block.timestamp);
    }

    function _getAmount(
        address token
    ) internal view returns (uint256 ethPerToken) {
        address poolAddress = factoryInterface.getPair(WMATIC, token);
        if (poolAddress == address(0)) {
            return 0;
        }

        uint256 timeElapsed = uint256(lastTokenTimestamp[token]) -
            uint256(tokenToTimestampLast[token]);

        ethPerToken = _calculate(
            commulativeETHPriceReserve[token],
            commulativeAveragePriceReserve[token],
            timeElapsed,
            token
        );
    }

    function _calculate(
        uint256 latestCumulativePrice,
        uint256 oldCumulativePrice,
        uint256 timeElapsed,
        address token
    ) public view returns (uint256 assetValue) {
        FixedPoint.uq112x112 memory priceTemp = FixedPoint.uq112x112(
            uint224((latestCumulativePrice - oldCumulativePrice) / timeElapsed)
        );
        uint256 decimals = IERC20(token).decimals();
        assetValue = priceTemp.mul(10 ** decimals).decode144();
    }
}