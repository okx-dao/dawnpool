// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDepositNodeOperator.sol";
//import "../interface/IDawnDeposit.sol";
import "../interface/IDepositNodeManager.sol";
import "../base/DawnBase.sol";
import "../interface/IDepositContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interface/IDawnDeposit.sol";

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
    uint64 internal constant _PUBKEY_LENGTH = 48;
    uint64 internal constant _SIGNATURE_LENGTH = 96;
    /// @dev Deposit 1 ETH when a validator pubkey is added, so that other 1 eth can earn rewards
    uint128 internal constant _PRE_DEPOSIT_VALUE = 1 ether;

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
     * @param preSignatures Signatures deposit 1 ETH
     * @param depositSignatures Signatures deposit 31 ETH
     * @return startIndex The first index of validators added
     * @return count Added validators count
     */
    function addValidators(
        bytes calldata pubkeys,
        bytes calldata preSignatures,
        bytes calldata depositSignatures
    ) external payable returns (uint256 startIndex, uint256 count) {
        require(msg.sender == getOperator(), "Only operator can add validators!");
        require(depositSignatures.length == preSignatures.length, "Inconsistent deposit signatures len!");
        require(pubkeys.length % _PUBKEY_LENGTH == 0, "Inconsistent public keys len!");
        require(preSignatures.length % _SIGNATURE_LENGTH == 0, "Inconsistent signatures len!");
        count = pubkeys.length / _PUBKEY_LENGTH;
        require(preSignatures.length / _SIGNATURE_LENGTH == count, "Inconsistent signatures count!");
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
            bytes memory preSignature = preSignatures[i * _SIGNATURE_LENGTH: i * _SIGNATURE_LENGTH + _SIGNATURE_LENGTH];
            bytes memory depositSignature = depositSignatures[i * _SIGNATURE_LENGTH: i * _SIGNATURE_LENGTH + _SIGNATURE_LENGTH];
            _setBytes(_getPubkeyStorageKeyByValidatorIndex(startIndex + i), pubkey);
            _setBytes(_getSignatureStorageKeyByValidatorIndex(startIndex + i), depositSignature);
//            _setUint(_getPubkeyIDStorageKeyByPubkey(pubkey), startIndex + i);
            dawnDeposit.preActivateValidator(msg.sender, pubkey, preSignature);
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

    /// @dev Get the storage key of the validator pubkey
    function _getPubkeyStorageKeyByValidatorIndex(uint256 index) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeOperator.pubkey", index));
    }

    /// @dev Get the storage key of the validator signature
    function _getSignatureStorageKeyByValidatorIndex(uint256 index) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeOperator.signature", index));
    }

//    /// @dev Get the storage key of the validator pubkey
//    function _getPubkeyIDStorageKeyByPubkey(bytes memory pubkey) internal pure returns (bytes32) {
//        return keccak256(abi.encodePacked("DepositNodeOperator.pubkeyID", pubkey));
//    }

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
}
