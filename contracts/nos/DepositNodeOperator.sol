// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDepositNodeOperator.sol";
//import "../interface/IDawnDeposit.sol";
import "../interface/IDepositNodeManager.sol";
import "../base/DawnBase.sol";
import "../interface/IDepositContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDawnDeposit {
    function stake() external payable returns (uint256);

    // deposit 31 ETH to activate validator
    function activateValidator(
        address operator,
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external;

    // deposit 1 ETH for NodeOperatorRegister
    function preActivateValidator(
        address operator,
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external;

    function getEtherByPEth(uint256 pEthAmount) external view returns (uint256);
}

/**
 * @title Node operator contract
 * @author Ray
 * @notice Node operator add his validator pubkeys through his node operator contract
 * @dev Node operator needs to stake specified amount of ETH to add a validator through this contract
 * The staked ETH will be transferred to dawn deposit pool and the returned pETH locked in this contract
 * It will be claimable if the operator exit his validators
 * However, the "overflow" part of shares can be claimed with validator rewards
 */
contract DepositNodeOperator is IDepositNodeOperator, DawnBase {
    uint32 internal constant _PUBKEY_LENGTH = 48;
    uint32 internal constant _SIGNATURE_LENGTH = 96;
    uint32 internal constant _DEPOSIT_DATA_ROOT_LEN = 32;
    uint32 internal constant __RESERVE_PARAM = 0;
    /// @dev Deposit 1 ETH when a validator pubkey is added, so that other 1 eth can earn rewards
    uint128 internal constant _PRE_DEPOSIT_VALUE = 1 ether;

    enum ValidatorStatus {
        NOT_EXIST,
        WAITING_ACTIVATED,
        VALIDATING,
        EXITING,
        SLASHING,
        EXITED
    }

    /**
     * @dev Constructor
     * @param operator Address of node operator
     * @param dawnStorage Storage address
     */
    constructor(address operator, IDawnStorageInterface dawnStorage) DawnBase(dawnStorage) {
        require(operator != address(0), "Operator address cannot be 0x0!");
        _setAddress(_getOperatorStorageKey(), operator);
    }

    /**
     * @notice Get node operator address
     * @return Node operator address
     */
    function getOperator() public view returns (address) {
        return _getAddress(_getOperatorStorageKey());
    }

    /**
     * @notice Add stakes for operator, and any account can do this
     * @return Minted pETH amount
     */
    function addStakes() external payable returns (uint256) {
        return IDawnDeposit(_getDawnDeposit()).stake{value: msg.value}();
    }

    /**
     * @notice Add validator pubkeys and signatures
     * @dev Make sure to have enough stakes to add validators
     * @param pubkeys Public keys
     * @param signatures Signatures
     * @param depositDataRoots deposit data roots
     * @return startIndex The first index of validators added
     * @return count Added validators count
     */
    function addValidators(
        bytes calldata pubkeys,
        bytes calldata signatures,
        bytes calldata depositDataRoots
    ) external payable returns (uint256 startIndex, uint256 count) {
        require(msg.sender == getOperator(), "Only operator can add validators!");
        require(pubkeys.length % _PUBKEY_LENGTH == 0, "Inconsistent public keys len!");
        require(signatures.length % _SIGNATURE_LENGTH == 0, "Inconsistent signatures len!");
        require(depositDataRoots.length % _DEPOSIT_DATA_ROOT_LEN == 0, "Inconsistent deposit data roots len!");
        count = pubkeys.length / _PUBKEY_LENGTH;
        require(signatures.length / _SIGNATURE_LENGTH == count, "Inconsistent signatures count!");
        require(depositDataRoots.length / _DEPOSIT_DATA_ROOT_LEN == count, "Inconsistent deposit data roots count!");
        IDawnDeposit dawnDeposit = IDawnDeposit(_getDawnDeposit());
        if (msg.value > 0) {
            dawnDeposit.stake{value: msg.value}();
        }
        uint256 operatorBalance = dawnDeposit.getEtherByPEth(IERC20(address(dawnDeposit)).balanceOf(address(this)));
        IDepositNodeManager nodeManager = IDepositNodeManager(_getDepositNodeManager());
        uint256 nextActiveValidatorsCount = getActiveValidatorsCount() + count;
        uint256 requiredAmount = nodeManager.getMinOperatorStakingAmount() * nextActiveValidatorsCount;
        require(operatorBalance >= requiredAmount, "Not enough deposits!");
        startIndex = nodeManager.registerValidators(msg.sender, count);
        for (uint256 i = 0; i < count; ++i) {
            bytes memory pubkey = pubkeys[i * _PUBKEY_LENGTH: i * _PUBKEY_LENGTH + _PUBKEY_LENGTH];
            bytes memory signature = signatures[i * _SIGNATURE_LENGTH: i * _SIGNATURE_LENGTH + _SIGNATURE_LENGTH];
            bytes32 depositDataRoot = bytes32(depositDataRoots[i * _DEPOSIT_DATA_ROOT_LEN: i * _DEPOSIT_DATA_ROOT_LEN + _DEPOSIT_DATA_ROOT_LEN]);
            require(_getBool(_getPublicKeyStorageKey(pubkey)) == false, "Public key has already exist!");
            _setBool(_getPublicKeyStorageKey(pubkey), true);
            dawnDeposit.preActivateValidator(msg.sender, pubkey, signature, depositDataRoot);
            emit SigningKeyAdded(startIndex + i, pubkey);
        }
        _setUint(_getActiveValidatorsCountStorageKey(), nextActiveValidatorsCount);
    }

    /**
     * @notice Get active validators of node operator, including includes all status, except exited
     * @return Active validators count
     */
    function getActiveValidatorsCount() public view returns (uint256) {
        return _getUint(_getActiveValidatorsCountStorageKey());
    }

    /**
     * @notice Get validating validators of node operator, only VALIDATING
     * @return Active validators count
     */
    function getValidatingValidatorsCount() external view returns (uint256) {
        return _getUint(_getValidatingValidatorsCountStorageKey());
    }

    /**
     * @notice Get WithdrawalCredentials
     */
    function getWithdrawalCredentials() public view returns (bytes32) {
        address rewardsVault = _getContractAddress("RewardsVault");
        return bytes32(bytes.concat(bytes12(0x010000000000000000000000), bytes20(rewardsVault)));
    }

    /// @dev Get address of dawn deposit contract
    function _getDawnDeposit() internal view returns (address) {
        return _getContractAddressUnsafe("DawnDeposit");
    }

    /// @dev Get DepositNodeManager contract address
    function _getDepositNodeManager() internal view returns (address) {
        return _getContractAddressUnsafe("DepositNodeManager");
    }

    /// @dev Get the operator storage key
    function _getOperatorStorageKey() internal view returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeOperator.operator", address(this)));
    }

    /// @dev Get active validators count storage key
    function _getActiveValidatorsCountStorageKey() internal view returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeOperator.ACTIVE_VALIDATORS_COUNT", getOperator()));
    }

    /// @dev Get validating validators count storage key, only VALIDATING status
    function _getValidatingValidatorsCountStorageKey() internal view returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeOperator.VALIDATING_VALIDATORS_COUNT", getOperator()));
    }

    /// @dev Get public key storage key
    function _getPublicKeyStorageKey(bytes memory pubkey) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeOperator.PUBLIC_KEY", pubkey));
    }
}
