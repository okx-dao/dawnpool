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
    uint256 internal constant _DEPOSIT_BASE = 32 ether;
    /// @dev Next validator index. Added one by one
    bytes32 internal constant _NEXT_VALIDATOR_ID = keccak256("DepositNodeManager.NEXT_VALIDATOR_ID");
    /// @dev Available validator pubkeys count
    bytes32 internal constant _AVAILABLE_VALIDATOR_COUNT = keccak256("DepositNodeManager.AVAILABLE_VALIDATOR_COUNT");
    bytes32 internal constant _MIN_OPERATOR_STAKING_AMOUNT =
        keccak256("DepositNodeManager.MIN_OPERATOR_STAKING_AMOUNT");
    bytes32 internal constant _OPERATOR_CREATION_SALT = keccak256("DepositNodeManager.OPERATOR_CREATION_SALT");

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
     * @notice Get available validator pubkeys count
     * @return Available validator pubkeys count
     * Only validators signed pre-exit msg can really get funds and be activated
     */
    function getAvailableValidatorsCount() public view returns (uint256) {
        return _getUint(_AVAILABLE_VALIDATOR_COUNT);
    }

    /**
     * @notice Node operators register validators and get operator index in return
     * @dev Function called when operators add pubkeys
     * @param operator Node operator address, for access control
     * @param count Node operator count request to register
     * @return The first index of validators registered
     */
    function registerValidators(address operator, uint256 count) external returns (uint256) {
        (address nodeAddress, bool isActive) = getNodeOperator(operator);
        require(msg.sender == nodeAddress, "Only node operator can register validators!");
        require(isActive, "Node operator is inactive!");
        uint256 startIndex = _getUint(_NEXT_VALIDATOR_ID);
        bytes32 validatorStorageKey;
        for (uint i = 0; i < count; ++i) {
            validatorStorageKey = _getStorageKeyByValidatorIndex(startIndex + i);
            _setAddress(validatorStorageKey, msg.sender);
            _setUint(validatorStorageKey, uint(ValidatorStatus.WAITING_ACTIVATED));
        }
        _setUint(_NEXT_VALIDATOR_ID, startIndex + count);
        _addUint(_AVAILABLE_VALIDATOR_COUNT, count);
        emit NodeValidatorsRegistered(nodeAddress, startIndex, count);
        return startIndex;
    }

    /**
     * @notice Get contract and status of validator by index
     * @param validatorIndex Index of validator
     * @return nodeAddress Node operator contract address the validator belongs to
     * @return status Validator status
     */
    function getNodeValidator(
        uint256 validatorIndex
    ) external view returns (address nodeAddress, ValidatorStatus status) {
        bytes32 validatorStorageKey = _getStorageKeyByValidatorIndex(validatorIndex);
        nodeAddress = _getAddress(validatorStorageKey);
        status = ValidatorStatus(_getUint(validatorStorageKey));
    }

    /// @notice Set minimum deposit amount, may be changed by DAO
    function setMinOperatorStakingAmount(uint256 minAmount) external onlyGuardian {
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
}
