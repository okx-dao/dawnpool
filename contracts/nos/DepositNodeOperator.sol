// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "../interface/IDepositNodeOperator.sol";
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
    string internal constant _DEPOSIT_NODE_MANAGER_CONTRACT_NAME = "DepositNodeManager";

    error ZeroAddress();
    error OperatorAccessDenied();
    error IncorrectPubkeysSignaturesLen(uint256 pubkeysLen, uint256 preSignaturesLen, uint256 depositSignaturesLen);
    error NotEnoughDeposits(uint256 required, uint256 current);
    error InvalidPubkeyLen(uint256 len);
    error InvalidSignatureLen(uint256 len);
    error TokenTransferFailed();

    /**
     * @dev Constructor
     * @param operator Address of node operator
     * @param dawnStorage Storage address
     */
    constructor(address operator, IDawnStorageInterface dawnStorage) DawnBase(dawnStorage) {
        if (operator == address(0)) revert ZeroAddress();
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
        if (msg.sender != getOperator()) revert OperatorAccessDenied();
        count = pubkeys.length / _PUBKEY_LENGTH;
        if (
            depositSignatures.length != preSignatures.length ||
            pubkeys.length % _PUBKEY_LENGTH != 0 ||
            preSignatures.length % _SIGNATURE_LENGTH != 0 ||
            preSignatures.length / _SIGNATURE_LENGTH != count
        ) revert IncorrectPubkeysSignaturesLen(pubkeys.length, preSignatures.length, depositSignatures.length);
        IDawnDeposit dawnDeposit = IDawnDeposit(_getDawnDeposit());
        if (msg.value > 0) {
            dawnDeposit.stake{value: msg.value}();
        }
        uint256 operatorBalance = dawnDeposit.getEtherByPEth(IERC20(address(dawnDeposit)).balanceOf(address(this)));
        IDepositNodeManager nodeManager = IDepositNodeManager(_getDepositNodeManager());
        uint256 nextActiveValidatorsCount = getActiveValidatorsCount() + count;
        uint256 requiredAmount = _getMinOperatorStakingAmount() * nextActiveValidatorsCount;
        if (operatorBalance < requiredAmount) revert NotEnoughDeposits(requiredAmount, operatorBalance);
        uint256 index;
        for (uint256 i = 0; i < count; ++i) {
            bytes memory pubkey = pubkeys[i * _PUBKEY_LENGTH:i * _PUBKEY_LENGTH + _PUBKEY_LENGTH];
            bytes memory preSignature = preSignatures[i * _SIGNATURE_LENGTH:i * _SIGNATURE_LENGTH + _SIGNATURE_LENGTH];
            bytes memory depositSignature = depositSignatures[i * _SIGNATURE_LENGTH:i *
                _SIGNATURE_LENGTH +
                _SIGNATURE_LENGTH];
            dawnDeposit.preActivateValidator(msg.sender, pubkey, preSignature);
            index = nodeManager.registerValidator(msg.sender, pubkey);
            _setBytes(_getSignatureStorageKeyByValidatorIndex(index), depositSignature);
        }
        _setUint(_getActiveValidatorsCountStorageKey(), nextActiveValidatorsCount);
        startIndex = index + 1 - count;
    }

    /**
     * @notice Activate a validator
     * @param index Validator index
     * @param pubkey Validator public key
     */
    function activateValidator(
        uint256 index,
        bytes calldata pubkey
    ) external onlyLatestContract(_DEPOSIT_NODE_MANAGER_CONTRACT_NAME, msg.sender) {
        if (pubkey.length != _PUBKEY_LENGTH) revert InvalidPubkeyLen(pubkey.length);
        bytes32 sigStorageKey = _getSignatureStorageKeyByValidatorIndex(index);
        bytes memory signature = _getBytes(sigStorageKey);
        if (signature.length != _SIGNATURE_LENGTH) revert InvalidSignatureLen(signature.length);
        IDawnDeposit(_getDawnDeposit()).activateValidator(getOperator(), pubkey, signature);
        _deleteBytes(sigStorageKey);
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
        return _getUint(keccak256(abi.encodePacked("DepositNodeManager.validatingValidatorsCount", getOperator())));
    }

    /// @notice Get the operator claimable staking and node rewards
    function getClaimableRewards() external view returns (uint256) {
        return
            _getStakeRewards(_getDawnDeposit()) +
            IDepositNodeManager(_getDepositNodeManager()).getClaimableNodeRewards(getOperator());
    }

    /// @notice Claim the operator staking and node rewards
    function claimRewards() external {
        address dawnDeposit = _getDawnDeposit();
        uint256 stakeRewards = _getStakeRewards(dawnDeposit);
        address operator = getOperator();
        IDepositNodeManager nodeManager = IDepositNodeManager(_getDepositNodeManager());
        if (stakeRewards > 0) {
            address withdrawAddress = nodeManager.getWithdrawAddress(operator);
            if (!IERC20(dawnDeposit).transfer(withdrawAddress, stakeRewards)) {
                revert TokenTransferFailed();
            }
            emit NodeOperatorStakingRewardsClaimed(msg.sender, withdrawAddress, stakeRewards);
        }
        nodeManager.claimNodeRewards(operator);
    }

    /**
     * @notice Change validators status before operator exit his validators
     * @param indexes Validators indexes will exit
     * @dev Node operator can exit his validators anytime, but need to change contract validator status first
     */
    function voluntaryExitValidators(uint256[] calldata indexes) external {
        address operator = getOperator();
        if (msg.sender != operator) revert OperatorAccessDenied();
        IDepositNodeManager(_getDepositNodeManager()).operatorRequestToExitValidators(operator, indexes);
        _subUint(_getActiveValidatorsCountStorageKey(), indexes.length);
    }

    /**
     * @notice Update validators exit count
     * @param count Validators exit count
     */
    function updateValidatorExitCount(
        uint256 count
    ) external onlyLatestContract(_DEPOSIT_NODE_MANAGER_CONTRACT_NAME, msg.sender) {
        _subUint(_getActiveValidatorsCountStorageKey(), count);
    }

    /// @dev Get the storage key of the validator signature
    function _getSignatureStorageKeyByValidatorIndex(uint256 index) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeOperator.signature", index));
    }

    /// @dev Get address of dawn deposit contract
    function _getDawnDeposit() internal view returns (address) {
        return _getContractAddressUnsafe("DawnDeposit");
    }

    /// @dev Get DepositNodeManager contract address
    function _getDepositNodeManager() internal view returns (address) {
        return _getContractAddressUnsafe(_DEPOSIT_NODE_MANAGER_CONTRACT_NAME);
    }

    /// @dev Get the operator storage key
    function _getOperatorStorageKey() internal view returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeOperator.operator", address(this)));
    }

    /// @dev Get active validators count storage key
    function _getActiveValidatorsCountStorageKey() internal view returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeOperator.ACTIVE_VALIDATORS_COUNT", getOperator()));
    }

    function _getStakeRewards(address dawnDeposit) internal view returns (uint256) {
        uint256 operatorBalance = IERC20(dawnDeposit).balanceOf(address(this));
        uint256 requiredAmount = IDawnDeposit(dawnDeposit).getPEthByEther(
            _getMinOperatorStakingAmount() * getActiveValidatorsCount()
        );
        if (operatorBalance > requiredAmount) {
            return operatorBalance - requiredAmount;
        }
        return 0;
    }

    function _getMinOperatorStakingAmount() internal view returns (uint256) {
        return _getUint(keccak256("DepositNodeManager.MIN_OPERATOR_STAKING_AMOUNT"));
    }
}
