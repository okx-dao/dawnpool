// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDepositNodeManager.sol";
import "../interface/IDepositNodeOperatorDeployer.sol";
import "../interface/IDepositNodeOperator.sol";
import "../base/DawnBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interface/IDawnDeposit.sol";

/**
 * @title Dawn node operator manager contract
 * @author Ray
 * @notice Dawn group members manage their node operators by this contract
 */
contract DepositNodeManager is IDepositNodeManager, DawnBase {
    /// @dev Next validator index. Added one by one
    bytes32 internal constant _NEXT_VALIDATOR_ID = keccak256("DepositNodeManager.NEXT_VALIDATOR_ID");
    /// @dev Available validator pubkeys count
    bytes32 internal constant _MIN_OPERATOR_STAKING_AMOUNT =
        keccak256("DepositNodeManager.MIN_OPERATOR_STAKING_AMOUNT");
    bytes32 internal constant _ACTIVATED_VALIDATOR_COUNT = keccak256("DepositNodeManager.ACTIVATED_VALIDATOR_COUNT");
    bytes32 internal constant _TOTAL_REWARDS_PETH = keccak256("DepositNodeManager.TOTAL_REWARDS_PETH");
    bytes32 internal constant _REWARDS_PETH_PER_VALIDATOR = keccak256("DepositNodeManager.REWARDS_PETH_PER_VALIDATOR");
    bytes32 internal constant _NEXT_EXIT_VALIDATOR_ID = keccak256("DepositNodeManager.NEXT_EXIT_VALIDATOR_ID");
    string internal constant _VALIDATORS_EXIT_BUS_ORACLE_CONTRACT_NAME = "ValidatorsExitBusOracle";

    string internal constant _DAWN_DEPOSIT_CONTRACT_NAME = "DawnDeposit";
    string internal constant _DAWN_DEPOSIT_SECURITY_MODULE = "DawnDepositSecurityModule";

    error ZeroAddress();
    error OperatorAlreadyExist();
    error PubkeyAlreadyExist();
    error InconsistentNodeOperatorAddress(address operator, address required, address caller);
    error InactiveNodeOperator(address operator);
    error InconsistentValidatorStatus(uint256 index, uint256 required, uint256 current);
    error NotReceiveEnoughRewards(uint256 required, uint256 current);
    error NotExistOperator();
    error InconsistentValidatorOperator(uint256 index, address required, address current);

    /**
     * @dev Constructor
     * @param dawnStorage Storage address
     */
    constructor(IDawnStorageInterface dawnStorage) DawnBase(dawnStorage) {}

    /**
     * @notice Register an node operator and deploy a node operator contract for request address
     * @return Deployed node operator contract address, and set it active
     */
    function registerNodeOperator(address withdrawAddress) external returns (address) {
        if (withdrawAddress == address(0)) revert ZeroAddress();
        bytes32 operatorStorageKey = _getStorageKeyByOperatorAddress(msg.sender);
        if (_getAddress(operatorStorageKey) != address(0)) revert OperatorAlreadyExist();
        address nodeAddress = IDepositNodeOperatorDeployer(_getContractAddressUnsafe("DepositNodeOperatorDeployer"))
            .deployDepositNodeOperator(msg.sender);
        _setAddress(operatorStorageKey, nodeAddress);
        _setBool(operatorStorageKey, true);
        emit NodeOperatorRegistered(msg.sender, nodeAddress);
        emit NodeOperatorActiveStatusChanged(msg.sender, true);
        _setAddress(_getWithdrawAddressStorageKey(msg.sender), withdrawAddress);
        emit WithdrawAddressSet(msg.sender, withdrawAddress);
        return nodeAddress;
    }

    /**
     * @notice Get the node operator contract address and status
     * @param operator Node operator address
     * @return nodeAddress Node operator contract address
     * @return isActive Whether the operator is active
     */
    function getNodeOperator(address operator) public view returns (address nodeAddress, bool isActive) {
        bytes32 operatorStorageKey = _getStorageKeyByOperatorAddress(operator);
        nodeAddress = _getAddress(operatorStorageKey);
        isActive = _getBool(operatorStorageKey);
    }

    /**
     * @notice Node operators register validators and get operator index in return
     * @dev Function called when operators add pubkeys
     * @param operator Node operator address, for access control
     * @param pubkey Public key request to register
     * @return The first index of validators registered
     */
    function registerValidator(address operator, bytes calldata pubkey) external returns (uint256) {
        (address nodeAddress, bool isActive) = getNodeOperator(operator);
        if (msg.sender != nodeAddress) revert InconsistentNodeOperatorAddress(operator, nodeAddress, msg.sender);
        if (!isActive) revert InactiveNodeOperator(operator);
        bytes32 pubkeyStorageKey = _getStorageKeyByValidatorPubkey(pubkey);
        if (_getUint(pubkeyStorageKey) > 0 || _getBool(pubkeyStorageKey)) {
            revert PubkeyAlreadyExist();
        }
        uint256 index = _getUint(_NEXT_VALIDATOR_ID);
        bytes32 validatorStorageKey = _getStorageKeyByValidatorIndex(index);
        _setAddress(validatorStorageKey, operator);
        _setUint(validatorStorageKey, uint(ValidatorStatus.WAITING_ACTIVATED));
        _setBytes(validatorStorageKey, pubkey);
        _setUint(pubkeyStorageKey, index);
        if (index == 0) {
            _setBool(pubkeyStorageKey, true);
        }
        _addUint(_NEXT_VALIDATOR_ID, 1);
        emit SigningKeyAdded(index, operator, pubkey);
        return index;
    }

    /**
     * @notice Get contract and status of validator by index
     * @param index Index of validator
     * @return operator Operator address the validator belongs to
     * @return pubkey Public key
     * @return status Validator status
     */
    function getNodeValidator(
        uint256 index
    ) public view returns (address operator, bytes memory pubkey, ValidatorStatus status) {
        bytes32 validatorStorageKey = _getStorageKeyByValidatorIndex(index);
        operator = _getAddress(validatorStorageKey);
        pubkey = _getBytes(validatorStorageKey);
        status = ValidatorStatus(_getUint(validatorStorageKey));
    }

    /**
     * @notice Get contract and status of validator by pubkey
     * @param pubkey The public key of the validator
     * @return index The index of the validator
     * @return operator Operator address the validator belongs to
     * @return status Validator status
     */
    function getNodeValidator(
        bytes calldata pubkey
    ) external view returns (uint256 index, address operator, ValidatorStatus status) {
        bytes32 pubkeyStorageKey = _getStorageKeyByValidatorPubkey(pubkey);
        index = _getUint(pubkeyStorageKey);
        if (index > 0 || _getBool(pubkeyStorageKey)) {
            bytes32 validatorStorageKey = _getStorageKeyByValidatorIndex(index);
            operator = _getAddress(validatorStorageKey);
            status = ValidatorStatus(_getUint(validatorStorageKey));
        }
    }

    /**
     * @notice Get contract and status of validator by index
     * @param startIndex Start index of validators request to get
     * @param amount Amount of validators request to get, 0 means all
     * @return operators Operators addresses the validators belong to
     * @return pubkeys Public keys
     * @return statuses Validator statuses
     */
    function getNodeValidators(
        uint256 startIndex,
        uint256 amount
    ) external view returns (address[] memory operators, bytes[] memory pubkeys, ValidatorStatus[] memory statuses) {
        uint256 endIndex = _getUint(_NEXT_VALIDATOR_ID);
        if (startIndex >= endIndex) return (operators, pubkeys, statuses);
        if (amount != 0 && startIndex + amount < endIndex) {
            endIndex = startIndex + amount;
        }
        uint256 count = endIndex - startIndex;
        operators = new address[](count);
        pubkeys = new bytes[](count);
        statuses = new ValidatorStatus[](count);
        uint256 arrIndex = 0;
        for (uint256 index = startIndex; index < endIndex; ++index) {
            (operators[arrIndex], pubkeys[arrIndex], statuses[arrIndex]) = getNodeValidator(index);
            ++arrIndex;
        }
    }

    /**
     * @notice Activate validators by index
     * @param indexes Index array of validators to be activated
     */
    function activateValidators(
        uint256[] calldata indexes
    ) external onlyLatestContract(_DAWN_DEPOSIT_SECURITY_MODULE, msg.sender) {
        bytes32 storageKey;
        address operator;
        address nodeAddress;
        uint256 index;
        bool isActive;
        for (uint256 i = 0; i < indexes.length; ++i) {
            index = indexes[i];
            storageKey = _getStorageKeyByValidatorIndex(index);
            if (_getUint(storageKey) != uint256(ValidatorStatus.WAITING_ACTIVATED))
                revert InconsistentValidatorStatus(
                    index,
                    uint256(ValidatorStatus.WAITING_ACTIVATED),
                    _getUint(storageKey)
                );
            bytes memory pubkey = _getBytes(storageKey);
            operator = _getAddress(storageKey);
            (nodeAddress, isActive) = getNodeOperator(operator);
            if (!isActive) revert InactiveNodeOperator(operator);
            IDepositNodeOperator(nodeAddress).activateValidator(index, pubkey);
            _updateRewards(operator);
            _setUint(storageKey, uint256(ValidatorStatus.VALIDATING));
            _addUint(_getValidatingValidatorsCountStorageKey(operator), 1);
            emit SigningKeyActivated(index, operator, pubkey);
        }
        _addUint(_ACTIVATED_VALIDATOR_COUNT, indexes.length);
    }

    /// @notice Get total validators count including all status
    function getTotalValidatorsCount() external view returns (uint256) {
        return _getUint(_NEXT_VALIDATOR_ID);
    }

    /// @notice Get total activated validators count only including VALIDATING status
    function getTotalActivatedValidatorsCount() external view returns (uint256) {
        return _getUint(_ACTIVATED_VALIDATOR_COUNT);
    }

    /**
     * @notice Set validator unsafe, the validator which was deposited
     * and was set wrong withdraw credential should be slashed by Oracle
     * @param index Validator index
     * @param slashedPethAmount PETH amount to be slashed
     */
    function setValidatorUnsafe(
        uint256 index,
        uint256 slashedPethAmount
    ) external onlyLatestContract(_DAWN_DEPOSIT_SECURITY_MODULE, msg.sender) {
        /// set validator status unsafe
        bytes32 validatorStorageKey = _getStorageKeyByValidatorIndex(index);
        if (_getUint(validatorStorageKey) != uint256(ValidatorStatus.WAITING_ACTIVATED))
            revert InconsistentValidatorStatus(
                index,
                uint256(ValidatorStatus.WAITING_ACTIVATED),
                _getUint(validatorStorageKey)
            );
        _setUint(validatorStorageKey, uint256(ValidatorStatus.UNSAFE));
        /// set operator inactive
        address operator = _getAddress(validatorStorageKey);
        bytes32 operatorStorageKey = _getStorageKeyByOperatorAddress(operator);
        if (_getBool(operatorStorageKey)) {
            _setBool(operatorStorageKey, false);
            emit NodeOperatorActiveStatusChanged(operator, false);
        }
        /// slash the operator 2 peth and decrease pool 1 eth
        address nodeAddress = _getAddress(operatorStorageKey);
        _slashNodeOperator(nodeAddress, slashedPethAmount, 1 ether);
        IDepositNodeOperator(_getAddress(_getStorageKeyByOperatorAddress(operator))).updateValidatorExitCount(1);
        emit SigningKeyUnsafe(index, operator, _getBytes(validatorStorageKey), nodeAddress, slashedPethAmount);
    }

    /**
     * @notice Distribute node operator rewards PETH
     * @param pethAmount distributed amount
     */
    function distributeNodeOperatorRewards(
        uint256 pethAmount
    ) external onlyLatestContract(_DAWN_DEPOSIT_CONTRACT_NAME, msg.sender) {
        uint256 bufferedRewards = _getUint(_TOTAL_REWARDS_PETH);
        uint256 currentPETHBalance = IERC20(_getDawnDeposit()).balanceOf(address(this));
        if (currentPETHBalance < bufferedRewards + pethAmount)
            revert NotReceiveEnoughRewards(bufferedRewards + pethAmount, currentPETHBalance);
        uint256 rewardsAddedPerValidator = pethAmount / _getUint(_ACTIVATED_VALIDATOR_COUNT);
        _addUint(_REWARDS_PETH_PER_VALIDATOR, rewardsAddedPerValidator);
        _addUint(_TOTAL_REWARDS_PETH, pethAmount);
        emit NodeOperatorRewardsReceived(pethAmount, rewardsAddedPerValidator);
    }

    /// @notice Set minimum deposit amount, may be changed by DAO
    function setMinOperatorStakingAmount(uint256 minAmount) external onlyGuardian {
        emit MinOperatorStakingAmountSet(msg.sender, minAmount);
        _setUint(_MIN_OPERATOR_STAKING_AMOUNT, minAmount);
    }

    /// @notice Get minimum deposit amount, may be changed by DAO
    function getMinOperatorStakingAmount() external view returns (uint256) {
        return _getUint(_MIN_OPERATOR_STAKING_AMOUNT);
    }

    /// @notice Get the operator withdraw address
    function getWithdrawAddress(address operator) public view returns (address) {
        return _getAddress(_getWithdrawAddressStorageKey(operator));
    }

    /// @notice Set the operator withdraw address
    function setWithdrawAddress(address withdrawAddress) external {
        if (withdrawAddress == address(0)) revert ZeroAddress();
        address nodeAddress = _getAddress(_getStorageKeyByOperatorAddress(msg.sender));
        if (nodeAddress == address(0)) revert NotExistOperator();
        _setAddress(_getWithdrawAddressStorageKey(msg.sender), withdrawAddress);
        emit WithdrawAddressSet(msg.sender, withdrawAddress);
    }

    /// @notice Get the operator claimable node rewards(commission)
    function getClaimableNodeRewards(address operator) external view returns (uint256) {
        return
            _getClaimableNodeRewards(
                operator,
                _getUint(_getClaimedRewardsPerValidatorStorageKey(operator)),
                _getUint(_REWARDS_PETH_PER_VALIDATOR)
            );
    }

    /// @notice Claim the operator node rewards(commission)
    function claimNodeRewards(address operator) external {
        _updateRewards(operator);
    }

    /**
     * @notice Change validators status before exit
     * @param count Validators count to change status
     * @dev Validators should exit firstly who joined at the earliest(least index)
     */
    function updateValidatorsExit(
        uint256 count
    )
        external
        onlyLatestContract(_VALIDATORS_EXIT_BUS_ORACLE_CONTRACT_NAME, msg.sender)
        returns (uint256[] memory indexes)
    {
        bytes32 validatorStorageKey;
        uint256 index = _getUint(_NEXT_EXIT_VALIDATOR_ID);
        uint256 nextValidatorId = _getUint(_NEXT_VALIDATOR_ID);
        uint256 exitCount = 0;
        uint256[] memory temp = new uint256[](count);
        while (exitCount < count && index < nextValidatorId) {
            validatorStorageKey = _getStorageKeyByValidatorIndex(index);
            if (_getUint(validatorStorageKey) != uint256(ValidatorStatus.VALIDATING)) {
                ++index;
                continue;
            }
            _exitOneValidator(index, validatorStorageKey);
            temp[exitCount] = index;
            ++index;
            ++exitCount;
        }
        indexes = new uint256[](exitCount);
        for (uint256 i = 0; i < exitCount; ++i) {
            indexes[i] = temp[i];
        }
        _setUint(_NEXT_EXIT_VALIDATOR_ID, index);
        _subUint(_ACTIVATED_VALIDATOR_COUNT, exitCount);
    }

    /**
     * @notice Change validators status before operator exit his validators
     * @param operator Node operator address
     * @param indexes Validators indexes will exit
     * @dev Node operator can exit his validators anytime, but need to change contract validator status first
     */
    function operatorRequestToExitValidators(address operator, uint256[] calldata indexes) external {
        address nodeAddress = _getAddress(_getStorageKeyByOperatorAddress(operator));
        if (msg.sender != nodeAddress) revert InconsistentNodeOperatorAddress(operator, nodeAddress, msg.sender);
        _updateRewards(operator);
        uint256 index;
        bytes32 validatorStorageKey;
        uint256 addedExitCount;
        for (uint256 i = 0; i < indexes.length; ++i) {
            index = indexes[i];
            validatorStorageKey = _getStorageKeyByValidatorIndex(index);
            if (_getAddress(validatorStorageKey) != operator)
                revert InconsistentValidatorOperator(index, _getAddress(validatorStorageKey), operator);
            if (_getUint(validatorStorageKey) != uint256(ValidatorStatus.VALIDATING))
                revert InconsistentValidatorStatus(
                    index,
                    uint256(ValidatorStatus.VALIDATING),
                    _getUint(validatorStorageKey)
                );
            _setUint(validatorStorageKey, uint256(ValidatorStatus.EXIT));
            emit SigningKeyExit(index, operator, _getBytes(validatorStorageKey));
            ++addedExitCount;
        }
        _subUint(_getValidatingValidatorsCountStorageKey(operator), addedExitCount);
        _subUint(_ACTIVATED_VALIDATOR_COUNT, addedExitCount);
    }

    /**
     * @notice Set validators status exit
     * @param index Validators index exited
     */
    function setValidatorExit(uint256 index) external onlyGuardian {
        /// set validator status exit
        bytes32 validatorStorageKey = _getStorageKeyByValidatorIndex(index);
        if (_getUint(validatorStorageKey) != uint256(ValidatorStatus.VALIDATING))
            revert InconsistentValidatorStatus(
                index,
                uint256(ValidatorStatus.VALIDATING),
                _getUint(validatorStorageKey)
            );
        _exitOneValidator(index, validatorStorageKey);
        _subUint(_ACTIVATED_VALIDATOR_COUNT, 1);
    }

    /**
     * @notice Set a validator slashing, the validator which was slashed will be punished a ETH immediately
     * and will be continuously punished for a long while, until it is forced out
     * @param index Validator index
     * @param slashedPethAmount PETH amount to be slashed
     * @param slashFinished Set the validator exit status if the param is true
     */
    function setValidatorSlashing(uint256 index, uint256 slashedPethAmount, bool slashFinished) external onlyGuardian {
        bytes32 validatorStorageKey = _getStorageKeyByValidatorIndex(index);
        address operator = _getAddress(validatorStorageKey);
        bytes32 operatorStorageKey = _getStorageKeyByOperatorAddress(operator);
        address nodeAddress = _getAddress(operatorStorageKey);
        _slashNodeOperator(nodeAddress, slashedPethAmount, 0);
        emit SigningKeySlashing(index, operator, _getBytes(validatorStorageKey), nodeAddress, slashedPethAmount);
        if (slashFinished) {
            if (_getUint(validatorStorageKey) != uint256(ValidatorStatus.SLASHING)) {
                revert InconsistentValidatorStatus(
                    index,
                    uint256(ValidatorStatus.SLASHING),
                    _getUint(validatorStorageKey)
                );
            }
            _setUint(validatorStorageKey, uint256(ValidatorStatus.EXIT));
            emit SigningKeyExit(index, operator, _getBytes(validatorStorageKey));
            IDepositNodeOperator(nodeAddress).updateValidatorExitCount(1);
        } else {
            if (_getUint(validatorStorageKey) != uint256(ValidatorStatus.VALIDATING)) {
                revert InconsistentValidatorStatus(
                    index,
                    uint256(ValidatorStatus.VALIDATING),
                    _getUint(validatorStorageKey)
                );
            }
            _updateRewards(operator);
            _setUint(validatorStorageKey, uint256(ValidatorStatus.SLASHING));
            _subUint(_getValidatingValidatorsCountStorageKey(operator), 1);
            _subUint(_ACTIVATED_VALIDATOR_COUNT, 1);
            if (_getBool(operatorStorageKey)) {
                _setBool(operatorStorageKey, false);
                emit NodeOperatorActiveStatusChanged(operator, false);
            }
        }
    }

    /**
     * @notice Punish one validator, maybe only can be called by DAO
     * @param index Validator index
     * @param slashedPethAmount PETH amount to be slashed
     * @param reason The reason why the validator is punished
     */
    function punishOneValidator(uint256 index, uint256 slashedPethAmount, bytes calldata reason) external onlyGuardian {
        bytes32 validatorStorageKey = _getStorageKeyByValidatorIndex(index);
        address operator = _getAddress(validatorStorageKey);
        address nodeAddress = _getAddress(_getStorageKeyByOperatorAddress(operator));
        _slashNodeOperator(nodeAddress, slashedPethAmount, 0);
        emit SigningKeyPunished(
            index,
            operator,
            _getBytes(validatorStorageKey),
            nodeAddress,
            slashedPethAmount,
            reason
        );
    }

    function setNodeOperatorActiveStatus(address operator, bool isActive) external onlyGuardian {
        bytes32 operatorStorageKey = _getStorageKeyByOperatorAddress(msg.sender);
        address nodeAddress = _getAddress(_getStorageKeyByOperatorAddress(operator));
        if (nodeAddress == address(0)) revert NotExistOperator();
        if (_getBool(operatorStorageKey) != isActive) {
            _setBool(operatorStorageKey, isActive);
            emit NodeOperatorActiveStatusChanged(operator, isActive);
        }
    }

    /// @dev Get the storage key of the operator
    function _getStorageKeyByOperatorAddress(address operator) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeManager.operator", operator));
    }

    /// @dev Get the storage key of the validator
    function _getStorageKeyByValidatorIndex(uint256 index) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeManager.validatorIndex", index));
    }

    ///
    function _getStorageKeyByValidatorPubkey(bytes calldata pubkey) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeManager.validatorPubkey", pubkey));
    }

    /// @dev Get the storage key of the node operator's validating validators count
    function _getValidatingValidatorsCountStorageKey(address operator) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeManager.validatingValidatorsCount", operator));
    }

    /// @dev Get the storage key of the node operator's claimed rewards per validator
    function _getClaimedRewardsPerValidatorStorageKey(address operator) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeManager.claimedRewardsPerValidator", operator));
    }

    /// @dev Update the node operator's rewards
    /// This function must be called before the node operator's validating validators count is changed
    function _updateRewards(address operator) internal {
        bytes32 claimedRewardsStorageKey = _getClaimedRewardsPerValidatorStorageKey(operator);
        uint256 claimedRewardsPerValidator = _getUint(claimedRewardsStorageKey);
        uint256 rewardsPerValidator = _getUint(_REWARDS_PETH_PER_VALIDATOR);
        uint256 claimableRewards = _getClaimableNodeRewards(operator, claimedRewardsPerValidator, rewardsPerValidator);
        if (claimableRewards > 0) {
            address withdrawAddress = getWithdrawAddress(operator);
            IERC20(_getDawnDeposit()).transfer(withdrawAddress, claimableRewards);
            _subUint(_TOTAL_REWARDS_PETH, claimableRewards);
            emit NodeOperatorNodeRewardsClaimed(operator, msg.sender, withdrawAddress, claimableRewards);
        }
        if (claimedRewardsPerValidator != rewardsPerValidator) {
            _setUint(claimedRewardsStorageKey, rewardsPerValidator);
        }
    }

    /// @dev Get the storage key of the operator withdraw address
    function _getWithdrawAddressStorageKey(address operator) internal pure returns (bytes32) {
        return sha256(abi.encodePacked("DepositNodeManager.operatorWithdrawAddress", operator));
    }

    function _getClaimableNodeRewards(
        address operator,
        uint256 claimedRewardsPerValidator,
        uint256 rewardsPerValidator
    ) internal view returns (uint256) {
        if (claimedRewardsPerValidator < rewardsPerValidator) {
            return
                (rewardsPerValidator - claimedRewardsPerValidator) *
                _getUint(_getValidatingValidatorsCountStorageKey(operator));
        }
        return 0;
    }

    function _exitOneValidator(uint256 index, bytes32 validatorStorageKey) internal {
        address operator = _getAddress(validatorStorageKey);
        _updateRewards(operator);
        _setUint(validatorStorageKey, uint256(ValidatorStatus.EXIT));
        _subUint(_getValidatingValidatorsCountStorageKey(operator), 1);
        emit SigningKeyExit(index, operator, _getBytes(validatorStorageKey));
        IDepositNodeOperator(_getAddress(_getStorageKeyByOperatorAddress(operator))).updateValidatorExitCount(1);
    }

    /// @dev Get address of dawn deposit contract
    function _getDawnDeposit() internal view returns (address) {
        return _getContractAddressUnsafe(_DAWN_DEPOSIT_CONTRACT_NAME);
    }

    function _slashNodeOperator(
        address nodeAddress,
        uint256 slashedPethAmount,
        uint256 decreaseEthAmount
    ) internal returns (uint256) {
        address dawnDeposit = _getDawnDeposit();
        uint256 nodeBalance = IERC20(dawnDeposit).balanceOf(nodeAddress);
        slashedPethAmount = slashedPethAmount <= nodeBalance ? slashedPethAmount : nodeBalance;
        if (slashedPethAmount == 0) return slashedPethAmount;
        if (decreaseEthAmount == 0) {
            IDawnDeposit(dawnDeposit).punish(nodeAddress, slashedPethAmount);
        } else {
            IDawnDeposit(dawnDeposit).punish(nodeAddress, slashedPethAmount, decreaseEthAmount);
        }
        return slashedPethAmount;
    }
}
