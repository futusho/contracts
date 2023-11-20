// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import {ERC20Mock} from "../lib/openzeppelin-contracts/contracts/mocks/ERC20Mock.sol";
import {FutuSho} from "../src/FutuSho.sol";
import {SellerMarketplace} from "../src/SellerMarketplace.sol";

contract FutuShoTest is Test {
    FutuSho private futusho;

    address deployer;
    address beneficiary;
    address seller;
    address buyer;

    function setUp() public {
        deployer = makeAddr("deployer");
        beneficiary = makeAddr("beneficiary");
        seller = makeAddr("seller");
        buyer = makeAddr("address");

        vm.prank(deployer);

        futusho = new FutuSho(beneficiary, 2);
    }

    function test_RegisterSeller_ReturnsError_IfCalledBySmartContract() public {
        vm.expectRevert("OnlyEOA");

        futusho.registerSeller("", "");
    }

    function test_RegisterSeller_ReturnsError_IfSellerIdIsEmpty() public {
        vm.startPrank(seller);

        vm.expectRevert("InvalidSellerID");

        futusho.registerSeller("", "");
    }

    function test_RegisterSeller_ReturnsError_IfMarketplaceIdIsEmpty() public {
        vm.startPrank(seller);

        vm.expectRevert("InvalidMarketplaceId");

        futusho.registerSeller("sellerId", "");
    }

    function test_RegisterSeller_Success_WithPaymentContracts() public {
        ERC20Mock token = new ERC20Mock();

        vm.prank(deployer);

        futusho.addPaymentContract(address(token));

        vm.prank(seller);

        futusho.registerSeller("sellerId", "marketplaceId");

        (bool exists, address marketplaceAddress) = futusho.getSellerMarketplace("sellerId", "marketplaceId");

        assertEq(exists, true);
        assertNotEq(marketplaceAddress, address(0));

        SellerMarketplace sellerMarketplace = SellerMarketplace(marketplaceAddress);
        assertEq(sellerMarketplace.sellerId(), "sellerId");
        assertEq(sellerMarketplace.marketplaceId(), "marketplaceId");
    }

    function test_GetSellerMarketplace_ReturnsEmptyValues_IfSellerDoesNotExist() public {
        (bool exists, address sellerMarketplace) = futusho.getSellerMarketplace("sellerId", "marketplaceId");

        assertEq(exists, false);
        assertEq(sellerMarketplace, address(0));
    }

    function test_GetSellerMarketplace_ReturnsEmptyValues_IfMarketplaceDoesNotExist() public {
        vm.startPrank(seller);

        futusho.registerSeller("sellerId", "marketplaceId");

        vm.stopPrank();

        (bool exists, address marketplaceAddress) = futusho.getSellerMarketplace("sellerId", "anotherMarketplaceId");

        assertEq(exists, false);
        assertEq(marketplaceAddress, address(0));
    }

    function test_GetSellerMarketplace_ReturnsValidValues() public {
        vm.startPrank(seller);

        futusho.registerSeller("sellerId", "marketplaceId");

        vm.stopPrank();

        (bool exists, address marketplaceAddress) = futusho.getSellerMarketplace("sellerId", "marketplaceId");

        assertEq(exists, true);
        assertNotEq(marketplaceAddress, address(0));

        SellerMarketplace sellerMarketplace = SellerMarketplace(marketplaceAddress);
        assertEq(sellerMarketplace.sellerAddress(), address(seller));
        assertEq(sellerMarketplace.sellerId(), "sellerId");
    }
}
