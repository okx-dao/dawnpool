// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDepositNodeManager.sol";
import "./DepositNodeOperator.sol";
import "../base/DawnBase.sol";

//import "../interface/IDawnDeposit.sol";

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
    bytes32 internal constant _OPERATOR_CREATION_SALT = keccak256("DepositNodeManager.OPERATOR_CREATION_SALT");
    bytes32 internal constant _ACTIVATED_VALIDATOR_COUNT = keccak256("DepositNodeManager.ACTIVATED_VALIDATOR_COUNT");
    bytes32 internal constant _TOTAL_REWARDS_PETH = keccak256("DepositNodeManager.TOTAL_REWARDS_PETH");
    bytes32 internal constant _REWARDS_PETH_PER_VALIDATOR = keccak256("DepositNodeManager.REWARDS_PETH_PER_VALIDATOR");
    string internal constant _DAWN_DEPOSIT_CONTRACT_NAME = "DawnDeposit";

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
        require(withdrawAddress != address(0), "Withdraw address can not be 0!");
        bytes32 operatorStorageKey = _getStorageKeyByOperatorAddress(msg.sender);
        require(_getAddress(operatorStorageKey) == address(0), "Operator already exist!");
        // Calculate address and set access
        address predictedAddress = address(
            uint160(
                uint(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            _OPERATOR_CREATION_SALT,
                            keccak256(
                                abi.encodePacked(
                                    type(DepositNodeOperator).creationCode,
                                    abi.encode(msg.sender, _dawnStorage)
                                )
                            )
                        )
                    )
                )
            )
        );
        _setBool(keccak256(abi.encodePacked("contract.exists", predictedAddress)), true);
        DepositNodeOperator nodeAddress = new DepositNodeOperator{salt: _OPERATOR_CREATION_SALT}(
            msg.sender,
            _dawnStorage
        );
        require(predictedAddress == address(nodeAddress), "Inconsistent predicted address!");
        _setAddress(operatorStorageKey, address(nodeAddress));
        _setBool(operatorStorageKey, true);
        _setUint(_getClaimedRewardsPerValidatorStorageKey(msg.sender), type(uint256).max); // init operator claimed rewards
        emit NodeOperatorRegistered(msg.sender, address(nodeAddress));
        _setAddress(_getWithdrawAddressStorageKey(msg.sender), withdrawAddress);
        emit WithdrawAddressSet(msg.sender, withdrawAddress);
        return address(nodeAddress);
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
        require(msg.sender == nodeAddress, "Only node operator can register validators!");
        require(isActive, "Node operator is inactive!");
        uint256 index = _getUint(_NEXT_VALIDATOR_ID);
        bytes32 validatorStorageKey = _getStorageKeyByValidatorIndex(index);
        _setAddress(validatorStorageKey, operator);
        _setUint(validatorStorageKey, uint(ValidatorStatus.WAITING_ACTIVATED));
        _setBytes(validatorStorageKey, pubkey);
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
    ) external view returns (address operator, bytes memory pubkey, ValidatorStatus status) {
        bytes32 validatorStorageKey = _getStorageKeyByValidatorIndex(index);
        operator = _getAddress(validatorStorageKey);
        pubkey = _getBytes(validatorStorageKey);
        status = ValidatorStatus(_getUint(validatorStorageKey));
    }

    /**
     * @notice Activate validators by index
     * @param indexes Index array of validators to be activated
     */
    function activateValidators(uint256[] calldata indexes) external onlyGuardian {
        bytes32 storageKey;
        address operator;
        address nodeAddress;
        uint256 index;
        for(uint256 i = 0; i < indexes.length; ++i){
            index = indexes[i];
            storageKey = _getStorageKeyByValidatorIndex(index);
            require(_getUint(storageKey) == uint256(ValidatorStatus.WAITING_ACTIVATED),
                "Validator status isn't waiting activated!");
            bytes memory pubkey = _getBytes(storageKey);
            operator = _getAddress(storageKey);
            nodeAddress = _getAddress(_getStorageKeyByOperatorAddress(operator));
            DepositNodeOperator(nodeAddress).activateValidator(index, pubkey);
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

    function setValidatorUnsafe(uint256 index, uint256 slashAmount) external onlyGuardian {

    }

    /**
     * @notice Distribute node operator rewards PETH
     * @param pethAmount distributed amount
     */
    function distributeNodeOperatorRewards(uint256 pethAmount) external onlyLatestContract(_DAWN_DEPOSIT_CONTRACT_NAME, msg.sender) {
        require(pethAmount > 0, "Can not distribute 0 rewards!");
        uint256 bufferedRewards = _getUint(_TOTAL_REWARDS_PETH);
        uint256 currentPETHBalance = IERC20(_getContractAddressUnsafe(_DAWN_DEPOSIT_CONTRACT_NAME)).balanceOf(address(this));
        require(currentPETHBalance >= bufferedRewards + pethAmount, "Not receive enough rewards!");
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
        require(withdrawAddress != address(0), "Withdraw address can not be 0x!");
        address nodeAddress = _getAddress(_getStorageKeyByOperatorAddress(msg.sender));
        require(nodeAddress != address(0), "Node operator is not exist!");
        _setAddress(_getWithdrawAddressStorageKey(msg.sender), withdrawAddress);
        emit WithdrawAddressSet(msg.sender, withdrawAddress);
    }

    /// @notice Get the operator claimable node rewards(commission)
    function getClaimableNodeRewards(address operator) external view returns (uint256) {
        return _getClaimableNodeRewards(
            operator,
                _getUint(_getClaimedRewardsPerValidatorStorageKey(operator)),
                _getUint(_REWARDS_PETH_PER_VALIDATOR)
        );
    }

    /// @notice Claim the operator node rewards(commission)
    function claimNodeRewards(address operator) external {
        _updateRewards(operator);
    }

    /// @dev Get the storage key of the operator
    function _getStorageKeyByOperatorAddress(address operator) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeManager.operator", operator));
    }

    /// @dev Get the storage key of the validator
    function _getStorageKeyByValidatorIndex(uint256 index) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeManager.validatorIndex", index));
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
        if(claimableRewards > 0) {
            address withdrawAddress = getWithdrawAddress(operator);
            IERC20(_getContractAddressUnsafe(_DAWN_DEPOSIT_CONTRACT_NAME)).transfer(withdrawAddress, claimableRewards);
            _subUint(_TOTAL_REWARDS_PETH, claimableRewards);
            emit NodeOperatorNodeRewardsClaimed(operator, msg.sender, withdrawAddress, claimableRewards);
        }
        if(claimedRewardsPerValidator != rewardsPerValidator) {
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
        if(claimedRewardsPerValidator < rewardsPerValidator) {
            return (rewardsPerValidator - claimedRewardsPerValidator)
            * _getUint(_getValidatingValidatorsCountStorageKey(operator))
            / _getUint(_ACTIVATED_VALIDATOR_COUNT);
        }
        return 0;
    }

}
