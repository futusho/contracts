// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// This token is used solely for development purposes during the deployment of the main smart contract.
contract MyToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("MyToken", "MYTOKEN") {
        _mint(msg.sender, initialSupply);
    }
}
