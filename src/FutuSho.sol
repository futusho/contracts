// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SellerMarketplace} from "./SellerMarketplace.sol";

/**
 * @title FutuSho
 * @dev FutuSho is a smart contract managing seller registration, payment contracts,
 * and associated marketplaces.
 */
contract FutuSho is Ownable {
    using Address for address;

    // Address of the beneficiary for platform commissions
    address public beneficiaryAddress;

    // Platform commission rate in percentage (1-5%)
    uint256 public platformCommissionRate;

    // Mapping to track registered sellers by their blockchain address
    mapping(address => bool) private registeredSellerByAddress;

    // Mapping to track registered sellers by their unique identifier
    mapping(string => address) private registeredSellerById;

    // Mapping to associate seller addresses with their marketplace contracts
    mapping(address => mapping(string => address)) private sellerMarketplace;

    // Mapping to check the existence of a payment contract
    mapping(address => bool) private paymentContractExists;

    // Mapping to store information about payment contracts
    mapping(uint256 => PaymentContract) private paymentContracts;

    // Mapping to get the index of a payment contract by its address
    mapping(address => uint256) private paymentContractIndexByAddress;

    // Count of total payment contracts
    uint256 private paymentContractsCount;

    // Count of enabled payment contracts
    uint256 private enabledPaymentContractsCount;

    // Struct representing a payment contract
    struct PaymentContract {
        bool enabled;
        address contractAddress;
    }

    // Struct representing a marketplace
    struct Marketplace {
        string sellerId;
        address sellerAddress;
        address marketplaceAddress;
    }

    // Event emitted when a new payment contract is added
    event PaymentContractAdded(address newPaymentContract);

    // Event emitted when a seller is registered
    // FIXME: I don't use indexed fields here, because wagmi can't handle it on the frontend side
    event SellerRegistered(
        address sellerAddress,
        string sellerId,
        string marketplaceId,
        address sellerMarketplace
    );

    // Modifier to ensure that the caller is an externally owned account (EOA)
    modifier onlyEOA() {
        require(!msg.sender.isContract(), "OnlyEOA");
        _;
    }

    /**
     * @dev Constructor to initialize FutuSho with the beneficiary address and
     * platform commission rate.
     * @param _beneficiaryAddress The address to receive platform commissions.
     * @param _platformCommissionRate The platform commission rate (1-5%).
     */
    constructor(address _beneficiaryAddress, uint256 _platformCommissionRate) {
        require(_beneficiaryAddress != address(0), "InvalidBeneficiary");
        require(_platformCommissionRate >= 1 && _platformCommissionRate <= 5, "InvalidCommission");

        beneficiaryAddress = _beneficiaryAddress;
        platformCommissionRate = _platformCommissionRate;
    }

    /**
     * @dev Adds a new payment contract to FutuSho.
     * @param newPaymentContract The address of the new payment contract.
     */
    function addPaymentContract(address newPaymentContract) external onlyOwner {
        require(newPaymentContract.isContract(), "InvalidContract");
        require(!paymentContractExists[newPaymentContract], "ContractExists");

        emit PaymentContractAdded(newPaymentContract);

        PaymentContract memory paymentContract = PaymentContract({
            enabled: true,
            contractAddress: newPaymentContract
        });

        paymentContractExists[newPaymentContract] = true;

        paymentContracts[paymentContractsCount] = paymentContract;
        paymentContractIndexByAddress[newPaymentContract] = paymentContractsCount;

        paymentContractsCount++;
        enabledPaymentContractsCount++;
    }

    /**
     * @dev Registers a seller with a unique seller ID and marketplace ID.
     * @param sellerId The unique identifier for the seller.
     * @param marketplaceId The unique identifier for the marketplace.
     */
    function registerSeller(string memory sellerId, string memory marketplaceId) external onlyEOA {
        require(bytes(sellerId).length > 0, "InvalidSellerID");
        require(bytes(marketplaceId).length > 0, "InvalidMarketplaceId");

        registeredSellerByAddress[msg.sender] = true;
        registeredSellerById[sellerId] = msg.sender;

        SellerMarketplace newSellerMarketplace = new SellerMarketplace(
            sellerId,
            marketplaceId,
            msg.sender,
            beneficiaryAddress,
            platformCommissionRate,
            getEnabledPaymentContracts()
        );

        // Associate the seller's address and marketplace ID with the new marketplace contract
        sellerMarketplace[msg.sender][marketplaceId] = address(newSellerMarketplace);

        // FIXME: We couldn't test this event at the moment,
        // because newSellerMarketplace is automatically generated
        emit SellerRegistered(msg.sender, sellerId, marketplaceId, address(newSellerMarketplace));
    }

    /**
     * @dev Gets the address of a seller's marketplace based on seller and marketplace IDs.
     * @param sellerId The unique identifier for the seller.
     * @param marketplaceId The unique identifier for the marketplace.
     * @return exists Whether the marketplace exists for the given seller and marketplace IDs.
     * @return marketplaceAddress The address of the marketplace.
     */
    function getSellerMarketplace(
        string memory sellerId,
        string memory marketplaceId
    ) external view returns (
        bool exists,
        address marketplaceAddress
    ) {
        address sellerAddress = registeredSellerById[sellerId];

        exists = sellerAddress != address(0)
            && registeredSellerByAddress[sellerAddress]
            && sellerMarketplace[sellerAddress][marketplaceId] != address(0);

        if (exists) {
            marketplaceAddress = sellerMarketplace[sellerAddress][marketplaceId];
        }
    }

    /**
     * @dev Gets an array of enabled payment contract addresses.
     * @return enabledContracts An array containing enabled payment contract addresses.
     */
    function getEnabledPaymentContracts() private view returns (address[] memory) {
        address[] memory enabledContracts = new address[](enabledPaymentContractsCount);
        uint256 contractIdx = 0;

        for (uint256 idx; idx < paymentContractsCount; idx++) {
            PaymentContract memory paymentContract = paymentContracts[idx];

            if (!paymentContract.enabled) continue;

            enabledContracts[contractIdx++] = paymentContract.contractAddress;
        }

        return enabledContracts;
    }
}
