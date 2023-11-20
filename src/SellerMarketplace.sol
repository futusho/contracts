// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title Seller Marketplace
 * @dev A smart contract representing a marketplace for a seller.
 */
contract SellerMarketplace is Ownable {
    using Address for address;

    // Order structure to store order details
    struct Order {
        address buyerAddress;
        uint256 price;
        uint256 sellerIncome;
        address paymentContract;
    }

    // Events emitted by the contract
    event PaymentContractAdded(address paymentContract);
    event PaymentContractDeleted(address paymentContract);
    event OrderPaid(
        address indexed buyerAddress,
        string indexed orderId,
        address indexed paymentContract
    );

    // Modifiers to restrict access to specific roles
    modifier onlySeller() {
        require(msg.sender == sellerAddress, "OnlySeller");
        _;
    }

    modifier onlyEOA() {
        require(!msg.sender.isContract(), "OnlyEOA");
        _;
    }

    // Contract state variables
    mapping(string => Order) private orders;
    mapping(address => bool) public allowedPaymentContracts;
    string public sellerId;
    string public marketplaceId;
    address public sellerAddress;
    address public beneficiaryAddress;
    uint256 public platformCommissionRate;

    /**
     * @dev Contract constructor.
     * @param _sellerId Unique identifier for the seller.
     * @param _marketplaceId Unique identifier for the marketplace.
     * @param _sellerAddress Address of the seller.
     * @param _beneficiaryAddress Address to receive commissions.
     * @param _platformCommissionRate Default commission rate for the platform.
     * @param _paymentContracts Array of allowed payment contracts.
     */
    constructor(
        string memory _sellerId,
        string memory _marketplaceId,
        address _sellerAddress,
        address _beneficiaryAddress,
        uint256 _platformCommissionRate,
        address[] memory _paymentContracts
    ) {
        sellerId = _sellerId;
        marketplaceId = _marketplaceId;
        sellerAddress = _sellerAddress;
        beneficiaryAddress = _beneficiaryAddress;
        platformCommissionRate = _platformCommissionRate;

        // Set allowed payment contracts
        for (uint256 idx; idx < _paymentContracts.length; idx++) {
            allowedPaymentContracts[_paymentContracts[idx]] = true;
        }
    }

    /**
     * @dev Adds a payment contract to the allowed list.
     * @param paymentContract Address of the payment contract.
     */
    function addPaymentContract(address paymentContract) external onlyOwner {
        require(paymentContract.isContract(), "NotEOA");

        if (allowedPaymentContracts[paymentContract]) return;

        allowedPaymentContracts[paymentContract] = true;

        emit PaymentContractAdded(paymentContract);
    }

    /**
     * @dev Deletes a payment contract from the allowed list.
     * @param paymentContract Address of the payment contract.
     */
    function deletePaymentContract(address paymentContract) external onlyOwner {
        require(paymentContract.isContract(), "NotEOA");

        if (!allowedPaymentContracts[paymentContract]) return;

        allowedPaymentContracts[paymentContract] = false;

        emit PaymentContractDeleted(paymentContract);
    }

    /**
     * @dev Processes a payment using native coins.
     * @param orderId Unique identifier for the order.
     * @param price Price of the order.
     */
    function payUsingCoin(string memory orderId, uint256 price) external payable onlyEOA {
        validatePaymentData(orderId, price);

        require(msg.value >= price, "InvalidValue");

        // Handle any excess payment by sending it back to the sender
        if (msg.value > price) {
            (bool excessSent, ) = payable(msg.sender).call{value: msg.value - price}("");
            require(excessSent, "Unable to send back excess amount of coins");
        }

        // FIXME: Should I reorder this up to prevent reentrancy attacks?
        uint256 commissionAmount = (price * platformCommissionRate) / 100;
        uint256 sellerIncome = price - commissionAmount;

        (bool paymentSent, ) = payable(beneficiaryAddress).call{value: commissionAmount}("");
        require(paymentSent, "Unable to pay using coin");

        saveOrderPayment(orderId, price, sellerIncome, address(0));
    }

    /**
     * @dev Processes a payment using ERC20 tokens.
     * @param orderId Unique identifier for the order.
     * @param price Price of the order.
     * @param paymentContract Address of the ERC20 payment contract.
     */
    function payUsingToken(string memory orderId, uint256 price, address paymentContract) external onlyEOA {
        validatePaymentData(orderId, price);

        require(allowedPaymentContracts[paymentContract], "InvalidContract");

        IERC20 token = IERC20(paymentContract);

        require(token.balanceOf(msg.sender) >= price, "InsufficientBalance");

        // FIXME: Should I reorder this up to prevent reentrancy attacks?
        uint256 commissionAmount = (price * platformCommissionRate) / 100;
        uint256 sellerIncome = price - commissionAmount;

        require(token.transferFrom(msg.sender, address(this), price), "Unable to transfer tokens to the marketplace");
        require(token.transfer(beneficiaryAddress, commissionAmount), "Unable to transfer commission");

        saveOrderPayment(orderId, price, sellerIncome, paymentContract);
    }

    /**
     * @dev Withdraws the entire balance of native coins to the seller's address.
     */
    function withdrawCoins() external onlySeller {
        uint256 contractBalance = address(this).balance;

        require(contractBalance > 0, "NoFundsAvailable");

        // TODO: Emit event

        (bool sent, ) = payable(sellerAddress).call{value: contractBalance}("");
        require(sent, "Unable to withdraw coins");
    }

    /**
     * @dev Withdraws a specific amount of native coins to the seller's address.
     * @param amount Amount of coins to withdraw.
     */
    function withdrawCoinsAmount(uint256 amount) external onlySeller {
        require(amount > 0, "ZeroAmount");

        uint256 contractBalance = address(this).balance;

        require(contractBalance > 0, "NoFundsAvailable");
        require(amount <= contractBalance, "InvalidAmount");

        // TODO: Emit event

        (bool sent, ) = payable(sellerAddress).call{value: amount}("");
        require(sent, "Unable to withdraw coins (amount)");
    }

    /**
     * @dev Withdraws the entire balance of ERC20 tokens to the seller's address.
     * @param tokenContract Address of the ERC20 token contract.
     */
    function withdrawTokens(address tokenContract) external onlySeller {
        require(allowedPaymentContracts[tokenContract], "InvalidContract");

        IERC20 token = IERC20(tokenContract);

        uint256 contractBalance = token.balanceOf(address(this));

        require(contractBalance > 0, "NoFundsAvailable");

        // TODO: Emit event

        require(token.transfer(sellerAddress, contractBalance), "Unable to withdraw tokens");
    }

    /**
     * @dev Withdraws a specific amount of ERC20 tokens to the seller's address.
     * @param tokenContract Address of the ERC20 token contract.
     * @param amount Amount of tokens to withdraw.
     */
    function withdrawTokensAmount(address tokenContract, uint256 amount) external onlySeller {
        require(allowedPaymentContracts[tokenContract], "InvalidContract");
        require(amount > 0, "ZeroAmount");

        IERC20 token = IERC20(tokenContract);

        uint256 contractBalance = token.balanceOf(address(this));

        require(contractBalance > 0, "NoFundsAvailable");
        require(amount <= contractBalance, "InvalidAmount");

        // TODO: Emit event

        require(token.transfer(sellerAddress, amount), "Unable to withdraw tokens (amount)");
    }

    /**
     * @dev Retrieves order details based on the order ID.
     * @param orderId Unique identifier for the order.
     * @return exists Whether the order exists.
     * @return buyerAddress Address of the buyer.
     * @return price Price of the order.
     * @return paymentContract Address of the payment contract (if applicable).
     */
    function getOrder(string memory orderId) external view returns (
        bool exists,
        address buyerAddress,
        uint256 price,
        address paymentContract
    ) {
        Order memory order = orders[orderId];

        exists = order.buyerAddress != address(0);

        if (exists) {
            buyerAddress = order.buyerAddress;
            price = order.price;
            paymentContract = order.paymentContract;
        }

        return (exists, buyerAddress, price, paymentContract);
    }

    /**
     * @dev Validates payment data before processing.
     * @param orderId Unique identifier for the order.
     * @param price Price of the order.
     */
    function validatePaymentData(string memory orderId, uint256 price) private view {
        require(bytes(orderId).length > 0, "InvalidOrderID");
        require(price > 0, "InvalidPrice");
        require(orders[orderId].buyerAddress == address(0), "OrderAlreadyPaid");
    }

    /**
     * @dev Saves the payment details for an order.
     * @param orderId Unique identifier for the order.
     * @param price Price of the order.
     * @param sellerIncome Income for the seller after deducting the commission.
     * @param paymentContract Address of the payment contract (if applicable).
     */
    function saveOrderPayment(
        string memory orderId,
        uint256 price,
        uint256 sellerIncome,
        address paymentContract
    ) private {
        orders[orderId] = Order(msg.sender, price, sellerIncome, paymentContract);

        emit OrderPaid(msg.sender, orderId, paymentContract);
    }
}
