// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";
import {FutuSho} from "../src/FutuSho.sol";

contract FutuShoScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address beneficiaryAddress = vm.envAddress("BENEFICIARY_ADDRESS");
        uint256 platformCommissionRate = vm.envUint("PLATFORM_COMMISSION_RATE");

        vm.startBroadcast(deployerPrivateKey);

        // Deploying and minting 1 million tokens with 18 decimals to the deployer's address.
        MyToken token = new MyToken(1000000 * 10 ** 18);

        // Deploying FutuSho contract owned by the first address from `make node` output.
        // The beneficiary address is set to the second address from `make node` for testing purposes.
        FutuSho futuSho = new FutuSho(beneficiaryAddress, platformCommissionRate);

        // Adding an extra payment token (which might be ERC20 stablecoin, etc.) to FutuSho.
        futuSho.addPaymentContract(address(token));
    }
}
