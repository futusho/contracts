// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import {SellerMarketplace} from "../src/SellerMarketplace.sol";
import {ERC20Mock} from "../lib/openzeppelin-contracts/contracts/mocks/ERC20Mock.sol";

contract FutuShoTest is Test {
    SellerMarketplace private marketplace;

    event PaymentContractAdded(address paymentContract);
    event OrderPaid(
        address indexed buyerAddress,
        string indexed orderId,
        address indexed paymentContract
    );

    address deployer;
    address beneficiary;
    address seller;
    address buyer;

    function setUp() public {
        deployer = makeAddr("deployer");
        beneficiary = makeAddr("beneficiary");
        seller = makeAddr("seller");
        buyer = makeAddr("address");

        address[] memory paymentContracts = new address[](0);

        vm.prank(deployer);
        marketplace = new SellerMarketplace("sellerId", "marketplaceId", seller, beneficiary, 2, paymentContracts);
    }

    function testConstructor() public {
        assertEq(marketplace.owner(), address(deployer));
        assertEq(marketplace.sellerId(), "sellerId");
        assertEq(marketplace.marketplaceId(), "marketplaceId");
        assertEq(marketplace.sellerAddress(), address(seller));
        assertEq(marketplace.beneficiaryAddress(), address(beneficiary));
        assertEq(marketplace.platformCommissionRate(), 2);
    }

    function test_AddPaymentContract_ReturnsError_IfCalledByNotAnOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");

        marketplace.addPaymentContract(address(0));
    }

    function test_AddPaymentContract_ReturnsError_IfAddressIsZero() public {
        vm.startPrank(deployer);

        vm.expectRevert("NotEOA");

        marketplace.addPaymentContract(address(0));
    }

    function test_AddPaymentContract_ReturnsError_IfPaymentContractIsEOA() public {
        vm.startPrank(deployer);

        vm.expectRevert("NotEOA");

        marketplace.addPaymentContract(address(seller));
    }

    function test_AddPaymentContract_Success_IfPaymentAlreadyAdded() public {
        ERC20Mock token = new ERC20Mock();

        vm.startPrank(deployer);

        marketplace.addPaymentContract(address(token));

        marketplace.addPaymentContract(address(token));
    }

    function test_AddPaymentContract_Success_EmitsEvent() public {
        ERC20Mock token = new ERC20Mock();

        vm.startPrank(deployer);

        vm.expectEmit(true, true, true, true);

        emit PaymentContractAdded(address(token));

        marketplace.addPaymentContract(address(token));
    }

    function test_PayUsingCoin_ReturnsError_IfCalledByContract() public {
        vm.expectRevert("OnlyEOA");

        marketplace.payUsingCoin("", 0);
    }

    function test_PayUsingCoin_ReturnsError_IfOrderIdIsEmptyString() public {
        vm.startPrank(buyer);

        vm.expectRevert("InvalidOrderID");

        marketplace.payUsingCoin("", 0);
    }

    function test_PayUsingCoin_ReturnsError_IfPriceIsZero() public {
        vm.startPrank(buyer);

        vm.expectRevert("InvalidPrice");

        marketplace.payUsingCoin("Order1", 0);
    }

    function test_PayUsingCoin_ReturnsError_WhenOrderAlreadyPaid() public {
        vm.deal(buyer, 1 ether);

        vm.startPrank(buyer);

        marketplace.payUsingCoin{value: 0.5 ether}("Order1", 0.5 ether);

        vm.expectRevert("OrderAlreadyPaid");

        marketplace.payUsingCoin{value: 0.5 ether}("Order1", 0.5 ether);
    }

    function test_PayUsingCoin_ReturnsError_IfValueHasNotBeenProvided() public {
        vm.startPrank(buyer);

        vm.expectRevert("InvalidValue");

        marketplace.payUsingCoin("Order1", 1);
    }

    function test_PayUsingCoin_Success_ReturnsExcessAmountOfMoneyBack() public {
        vm.deal(buyer, 1 ether);

        vm.startPrank(buyer);

        marketplace.payUsingCoin{value: 0.6 ether}("Order1", 0.5 ether);

        vm.stopPrank();

        assertEq(address(buyer).balance, 0.5 ether);
    }

    function test_PayUsingCoin_Success_KeepsTokensOnContract() public {
        vm.deal(buyer, 1 ether);

        vm.prank(buyer);

        marketplace.payUsingCoin{value: 0.5 ether}("Order1", 0.5 ether);

        assertEq(address(beneficiary).balance, 0.01 ether);
        assertEq(address(marketplace).balance, 0.49 ether);
        assertEq(address(buyer).balance, 0.5 ether);
    }

    function test_PayUsingCoin_Success_EmitsEvent() public {
        vm.deal(buyer, 1 ether);

        vm.expectEmit(true, true, true, true);

        emit OrderPaid(address(buyer), "Order1", address(0));

        vm.prank(buyer);

        marketplace.payUsingCoin{value: 0.5 ether}("Order1", 0.5 ether);
    }

    function test_PayUsingToken_ReturnsError_IfCalledByContract() public {
        vm.expectRevert("OnlyEOA");

        marketplace.payUsingToken("", 0, address(0));
    }

    function test_PayUsingToken_ReturnsError_IfOrderIdIsEmptyString() public {
        vm.startPrank(buyer);

        vm.expectRevert("InvalidOrderID");

        marketplace.payUsingToken("", 0, address(0));
    }

    function test_PayUsingToken_ReturnsError_IfPriceIsZero() public {
        vm.startPrank(buyer);

        vm.expectRevert("InvalidPrice");

        marketplace.payUsingToken("Order1", 0, address(0));
    }

    function test_PayUsingToken_ReturnsError_IfContractIsZero() public {
        vm.startPrank(buyer);

        vm.expectRevert("InvalidContract");

        marketplace.payUsingToken("Order1", 1, address(0));
    }

    function test_PayUsingToken_ReturnsError_IfPaymentContractDoesNotSupported() public {
        ERC20Mock token = new ERC20Mock();

        vm.startPrank(buyer);

        vm.expectRevert("InvalidContract");

        marketplace.payUsingToken("Order1", 1 ether, address(token));
    }

    function test_PayUsingToken_ReturnsError_WhenOrderAlreadyPaid() public {
        ERC20Mock token = new ERC20Mock();

        token.mint(address(buyer), 1 ether);

        vm.prank(deployer);

        marketplace.addPaymentContract(address(token));

        vm.startPrank(buyer);

        token.approve(address(marketplace), 1 ether);

        marketplace.payUsingToken("Order1", 0.5 ether, address(token));

        vm.expectRevert("OrderAlreadyPaid");

        marketplace.payUsingToken("Order1", 0.5 ether, address(token));
    }

    function test_PayUsingToken_ReturnsError_IfThereIsNoAllowance() public {
        ERC20Mock token = new ERC20Mock();

        token.mint(address(buyer), 1 ether);

        vm.prank(deployer);

        marketplace.addPaymentContract(address(token));

        vm.expectRevert("ERC20: insufficient allowance");

        vm.prank(buyer);

        marketplace.payUsingToken("Order1", 1 ether, address(token));
    }

    function test_PayUsingToken_ReturnsError_WhenInsufficientAllowance() public {
        ERC20Mock token = new ERC20Mock();

        token.mint(address(buyer), 1 ether);

        vm.prank(deployer);

        marketplace.addPaymentContract(address(token));

        vm.expectRevert("ERC20: insufficient allowance");

        vm.prank(buyer);

        marketplace.payUsingToken("Order1", 0.9 ether, address(token));
    }

    function test_PayUsingToken_ReturnsError_WhenInsufficientBalance() public {
        ERC20Mock token = new ERC20Mock();

        token.mint(address(buyer), 1 ether);

        vm.prank(deployer);

        marketplace.addPaymentContract(address(token));

        vm.startPrank(buyer);

        token.approve(address(marketplace), 1.1 ether);

        vm.expectRevert("InsufficientBalance");

        marketplace.payUsingToken("Order1", 1.1 ether, address(token));
    }

    function test_PayUsingToken_Success_TransfersTokensToMarketplace() public {
        ERC20Mock token = new ERC20Mock();

        token.mint(address(buyer), 0.5 ether);

        vm.prank(deployer);

        marketplace.addPaymentContract(address(token));

        vm.startPrank(buyer);

        token.approve(address(marketplace), 0.5 ether);

        marketplace.payUsingToken("Order1", 0.5 ether, address(token));

        vm.stopPrank();

        assertEq(token.balanceOf(address(beneficiary)), 0.01 ether);
        assertEq(token.balanceOf(address(marketplace)), 0.49 ether);
        assertEq(token.balanceOf(address(buyer)), 0);
    }

    function test_PayUsingToken_Success_EmitsEvent() public {
        ERC20Mock token = new ERC20Mock();

        token.mint(address(buyer), 0.5 ether);

        vm.prank(deployer);

        marketplace.addPaymentContract(address(token));

        vm.startPrank(buyer);

        token.approve(address(marketplace), 0.5 ether);

        vm.expectEmit(true, true, true, true);

        emit OrderPaid(address(buyer), "Order1", address(token));

        marketplace.payUsingToken("Order1", 0.5 ether, address(token));
    }

    function test_WithdrawCoins_ReturnsError_IfCalledByNotASeller() public {
        vm.expectRevert("OnlySeller");

        marketplace.withdrawCoins();
    }

    function test_WithdrawCoins_ReturnsError_IfBalanceIsZero() public {
        vm.startPrank(seller);

        vm.expectRevert("NoFundsAvailable");

        marketplace.withdrawCoins();
    }

    function test_WithdrawCoins_Success_TransfersCoinsToSeller() public {
        vm.deal(buyer, 0.5 ether);

        vm.startPrank(buyer);

        marketplace.payUsingCoin{value: 0.5 ether}("Order1", 0.5 ether);

        vm.stopPrank();

        assertEq(address(beneficiary).balance, 0.01 ether);
        assertEq(address(marketplace).balance, 0.49 ether);

        vm.startPrank(seller);

        marketplace.withdrawCoins();

        assertEq(address(marketplace).balance, 0);
        assertEq(address(seller).balance, 0.49 ether);
    }

    function test_WithdrawCoinsAmount_ReturnsError_IfCalledByNotASeller() public {
        vm.expectRevert("OnlySeller");

        marketplace.withdrawCoinsAmount(0);
    }

    function test_WithdrawCoinsAmount_ReturnsError_IfAmountIsZero() public {
        vm.startPrank(seller);

        vm.expectRevert("ZeroAmount");

        marketplace.withdrawCoinsAmount(0);
    }

    function test_WithdrawCoinsAmount_ReturnsError_IfBalanceIsZero() public {
        vm.startPrank(seller);

        vm.expectRevert("NoFundsAvailable");

        marketplace.withdrawCoinsAmount(1 wei);
    }

    function test_WithdrawCoinsAmount_ReturnsError_IfRequestedMoreThanAvailable() public {
        vm.deal(buyer, 0.5 ether);

        vm.startPrank(buyer);

        marketplace.payUsingCoin{value: 0.5 ether}("Order1", 0.5 ether);

        vm.stopPrank();

        assertEq(address(beneficiary).balance, 0.01 ether);
        assertEq(address(marketplace).balance, 0.49 ether);

        vm.startPrank(seller);

        vm.expectRevert("InvalidAmount");

        marketplace.withdrawCoinsAmount(0.5 ether);
    }

    function test_WithdrawCoinsAmount_Success_TransfersCoinsToSeller() public {
        vm.deal(buyer, 0.5 ether);

        vm.startPrank(buyer);

        marketplace.payUsingCoin{value: 0.5 ether}("Order1", 0.5 ether);

        vm.stopPrank();

        assertEq(address(beneficiary).balance, 0.01 ether);
        assertEq(address(marketplace).balance, 0.49 ether);

        vm.startPrank(seller);

        marketplace.withdrawCoinsAmount(0.48 ether);

        assertEq(address(marketplace).balance, 0.01 ether);
        assertEq(address(seller).balance, 0.48 ether);
    }

    function test_WithdrawTokens_ReturnsError_IfCalledByNotASeller() public {
        vm.expectRevert("OnlySeller");

        marketplace.withdrawTokens(address(0));
    }

    function test_WithdrawTokens_ReturnsError_IfContractDoesNotExist() public {
        vm.startPrank(seller);

        vm.expectRevert("InvalidContract");

        marketplace.withdrawTokens(address(0));
    }

    function test_WithdrawTokens_ReturnsError_IfContractBalanceIsZero() public {
        ERC20Mock token = new ERC20Mock();

        vm.prank(deployer);

        marketplace.addPaymentContract(address(token));

        vm.startPrank(seller);

        vm.expectRevert("NoFundsAvailable");

        marketplace.withdrawTokens(address(token));
    }

    function test_WithdrawTokens_Success_TransfersTokensToSeller() public {
        ERC20Mock token = new ERC20Mock();

        token.mint(address(buyer), 0.5 ether);

        vm.prank(deployer);

        marketplace.addPaymentContract(address(token));

        vm.startPrank(buyer);

        token.approve(address(marketplace), 0.5 ether);

        marketplace.payUsingToken("Order1", 0.5 ether, address(token));

        vm.stopPrank();

        vm.startPrank(seller);

        marketplace.withdrawTokens(address(token));

        assertEq(token.balanceOf(address(marketplace)), 0);
        assertEq(token.balanceOf(address(seller)), 0.49 ether);
    }

    function test_WithdrawTokensAmount_ReturnsError_IfCalledByNotASeller() public {
        vm.expectRevert("OnlySeller");

        marketplace.withdrawTokensAmount(address(0), 0);
    }

    function test_WithdrawTokensAmount_ReturnsError_IfContractDoesNotExist() public {
        vm.startPrank(seller);

        vm.expectRevert("InvalidContract");

        marketplace.withdrawTokensAmount(address(0), 0);
    }

    function test_WithdrawTokensAmount_ReturnsError_IfAmountIsZero() public {
        ERC20Mock token = new ERC20Mock();

        vm.prank(deployer);

        marketplace.addPaymentContract(address(token));

        vm.startPrank(seller);

        vm.expectRevert("ZeroAmount");

        marketplace.withdrawTokensAmount(address(token), 0);
    }

    function test_WithdrawTokensAmount_ReturnsError_IfContractBalanceIsZero() public {
        ERC20Mock token = new ERC20Mock();

        vm.prank(deployer);

        marketplace.addPaymentContract(address(token));

        vm.startPrank(seller);

        vm.expectRevert("NoFundsAvailable");

        marketplace.withdrawTokensAmount(address(token), 1 wei);
    }

    function test_WithdrawTokensAmount_ReturnsError_IfRequestedMoreThanAvailable() public {
        ERC20Mock token = new ERC20Mock();

        token.mint(address(buyer), 0.5 ether);

        vm.prank(deployer);

        marketplace.addPaymentContract(address(token));

        vm.startPrank(buyer);

        token.approve(address(marketplace), 0.5 ether);

        marketplace.payUsingToken("Order1", 0.5 ether, address(token));

        vm.stopPrank();

        vm.startPrank(seller);

        vm.expectRevert("InvalidAmount");

        marketplace.withdrawTokensAmount(address(token), 0.5 ether);
    }

    function test_WithdrawTokensAmount_Success_TransfersTokensToSeller() public {
        ERC20Mock token = new ERC20Mock();

        token.mint(address(buyer), 0.5 ether);

        vm.prank(deployer);

        marketplace.addPaymentContract(address(token));

        vm.startPrank(buyer);

        token.approve(address(marketplace), 0.5 ether);

        marketplace.payUsingToken("Order1", 0.5 ether, address(token));

        vm.stopPrank();

        vm.startPrank(seller);

        marketplace.withdrawTokensAmount(address(token), 0.48 ether);

        assertEq(token.balanceOf(address(marketplace)), 0.01 ether);
        assertEq(token.balanceOf(address(seller)), 0.48 ether);
    }

    function test_GetOrder_ReturnsEmptyValues_IfOrderDoesNotExist() public {
        (
            bool exists,
            address buyerAddress,
            uint256 price,
            address paymentContract
        ) = marketplace.getOrder("orderId");

        assertEq(exists, false);
        assertEq(buyerAddress, address(0));
        assertEq(price, 0);
        assertEq(paymentContract, address(0));
    }

    function test_GetOrder_ReturnsValidValues_WhenOrderWasPaidUsingCoin() public {
        vm.deal(buyer, 0.5 ether);

        vm.startPrank(buyer);

        marketplace.payUsingCoin{value: 0.5 ether}("Order1", 0.5 ether);

        vm.stopPrank();

        (
            bool exists,
            address buyerAddress,
            uint256 price,
            address paymentContract
        ) = marketplace.getOrder("Order1");

        assertEq(exists, true);
        assertEq(buyerAddress, address(buyer));
        assertEq(price, 0.5 ether);
        assertEq(paymentContract, address(0));
    }

    function test_GetOrder_ReturnsValidValues_WhenOrderWasPaidUsingTokens() public {
        ERC20Mock token = new ERC20Mock();

        token.mint(address(buyer), 0.5 ether);

        vm.prank(deployer);

        marketplace.addPaymentContract(address(token));

        vm.startPrank(buyer);

        token.approve(address(marketplace), 0.5 ether);

        marketplace.payUsingToken("Order1", 0.5 ether, address(token));

        vm.stopPrank();

        (
            bool exists,
            address buyerAddress,
            uint256 price,
            address paymentContract
        ) = marketplace.getOrder("Order1");

        assertEq(exists, true);
        assertEq(buyerAddress, address(buyer));
        assertEq(price, 0.5 ether);
        assertEq(paymentContract, address(token));
    }
}
