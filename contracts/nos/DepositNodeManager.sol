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
    /**
     * @dev Constructor
     * @param dawnStorage Storage address
     */
    constructor(IDawnStorageInterface dawnStorage) DawnBase(dawnStorage) {}

    /**
     * @notice Register an node operator and deploy a node operator contract for request address
     * @return Deployed node operator contract address, and set it active
     */
    function registerNodeOperator() external returns (address) {
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
        emit NodeOperatorRegistered(msg.sender, address(nodeAddress));
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
        uint256 index;
        for(uint256 i = 0; i < indexes.length; ++i){
            index = indexes[i];
            storageKey = _getStorageKeyByValidatorIndex(index);
            require(_getUint(storageKey) == uint256(ValidatorStatus.WAITING_ACTIVATED),
                "Validator status isn't waiting activated!");
            bytes memory pubkey = _getBytes(storageKey);
            operator = _getAddress(storageKey);
            DepositNodeOperator(_getAddress(_getStorageKeyByOperatorAddress(operator))).activateValidator(index, pubkey);
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

    function distributeNodeOperatorRewards(uint256 pethAmount) external onlyLatestContract("DawnDeposit", msg.sender) {
//        require(IERC20(_getContractAddressUnsafe("DawnDeposit")).balanceOf(address(this)))
    }

    /// @notice Set minimum deposit amount, may be changed by DAO
    function setMinOperatorStakingAmount(uint256 minAmount) external onlyGuardian {
        emit MinOperatorStakingAmountSet(msg.sender, _getUint(_MIN_OPERATOR_STAKING_AMOUNT), minAmount);
        _setUint(_MIN_OPERATOR_STAKING_AMOUNT, minAmount);
    }

    /// @notice Get minimum deposit amount, may be changed by DAO
    function getMinOperatorStakingAmount() external view returns (uint256) {
        return _getUint(_MIN_OPERATOR_STAKING_AMOUNT);
    }

    /// @dev Get the storage key of the operator
    function _getStorageKeyByOperatorAddress(address operator) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeManager.operator", operator));
    }

    /// @dev Get the storage key of the validator
    function _getStorageKeyByValidatorIndex(uint256 index) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeManager.validatorIndex", index));
    }

    function _getValidatingValidatorsCountStorageKey(address operatorAddress) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeManager.validatingValidatorsCount", operatorAddress));
    }
}
