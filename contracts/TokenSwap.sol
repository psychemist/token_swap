// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenSwap {
    error InsufficientContractBalance();
    error InsufficientSenderBalance();
    error InvalidOrderId();
    error InvalidTokenAddress();
    error OrderAlreadyFulfilled();
    error OrderFailed();
    error TokenAlreadyAdded();
    error TransferFailed();
    error ZeroAddressDetected();
    error ZeroAmountForbidden();

    address public owner;
    uint256 public orderCount;
    uint256 public tokenCount;

    struct Token {
        uint256 id;
        address tokenAdress;
        uint8 dollarRate;
    }
    Token[] tokens;

    struct Order {
        uint256 id;
        uint256 amount;
        address sender;
        address tokenA;
        address tokenB;
        bool isComplete;
    }
    Order[] orders;

    mapping(address => Token) allTokens;
    mapping(uint256 => Order) allOrders;
    mapping(address => bool) allowedTokens;
    // user address -> order id -> completed?
    mapping(address => mapping(uint => bool)) fulfilledOrders;

    event OrderPlaced(
        address user,
        address tokenA,
        address tokenB,
        uint256 amount
    );
    event TokensSwapped(
        address user,
        address tokenA,
        address tokenB,
        uint256 amount
    );
    event OrderClosed();

    constructor(address _owner) {
        owner = _owner;
    }

    function addToken(address _tokenAddress, uint8 _dollarRate) external {
        require(msg.sender != address(0), ZeroAddressDetected());
        require(_tokenAddress != address(0), ZeroAddressDetected());

        require(!allowedTokens[_tokenAddress], TokenAlreadyAdded());
        require(_dollarRate > 0, ZeroAmountForbidden());

        uint256 tokenId = ++tokenCount;

        Token memory tk = Token(tokenId, _tokenAddress, _dollarRate);
        tokens.push(tk);

        allowedTokens[_tokenAddress] = true;
    }

    function placeOrder(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn
    ) external {
        // _checkZeroAdress();
        require(msg.sender != address(0), ZeroAddressDetected());
        require(_tokenIn != address(0), ZeroAddressDetected());
        require(_tokenOut != address(0), ZeroAddressDetected());

        require(allowedTokens[_tokenIn], InvalidTokenAddress());
        require(allowedTokens[_tokenOut], InvalidTokenAddress());
        require(_amountIn > 0, ZeroAmountForbidden());

        uint256 orderId = ++orderCount;

        Order memory ord = Order(
            orderId,
            _amountIn,
            msg.sender,
            _tokenIn,
            _tokenOut,
            false
        );

        orders.push(ord);

        require(swapTokens(orderId), OrderFailed());

        emit OrderPlaced(msg.sender, _tokenIn, _tokenOut, _amountIn);
    }

    function swapTokens(uint256 _orderId) internal returns (bool success_) {
        require(msg.sender != address(0), ZeroAddressDetected());

        require(_orderId > 0, InvalidOrderId());
        require(
            !fulfilledOrders[msg.sender][_orderId],
            OrderAlreadyFulfilled()
        );

        Order memory ord = allOrders[_orderId];

        require(!ord.isComplete, OrderAlreadyFulfilled());

        uint256 swapAmount = getAmountOut(ord);

        require(
            IERC20(ord.tokenB).balanceOf(address(this)) > swapAmount,
            InsufficientContractBalance()
        );
        // require((ord.tokenA).balanceOf());

        require(
            IERC20(ord.tokenA).transferFrom(
                msg.sender,
                address(this),
                ord.amount
            ),
            InsufficientSenderBalance()
        );

        ord.isComplete = true;
        fulfilledOrders[msg.sender][ord.id] = true;

        success_ = IERC20(ord.tokenB).transfer(ord.sender, swapAmount);

        emit TokensSwapped(msg.sender, ord.tokenA, ord.tokenB, swapAmount);
    }

    function getAmountOut(
        Order memory ord
    ) internal view returns (uint256 amountOut_) {
        uint8 rate1 = allTokens[ord.tokenA].dollarRate;
        uint8 rate2 = allTokens[ord.tokenB].dollarRate;

        amountOut_ = (ord.amount * (rate2 * 1000)) / (rate1 * 1000);
    }

    // function cancelOrder(uint256 _orderId) {
    //     require(msg.sender != address(0), ZeroAddressDetected());
    //     require(_orderId > 0, InvalidOrderId());

    //     require(
    //         !fulfilledOrders[msg.sender][_orderId],
    //         OrderAlreadyFulfilled()
    //     );

    //     Order storage ord = allOrders[_orderId];

    //     require(!ord.isComplete, OrderAlreadyFulfilled());

    // }
}
