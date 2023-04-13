// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDepositNodeManager.sol";
import "./DepositNodeOperator.sol";
import "../base/DawnBase.sol";
import "../interface/IDawnDeposit.sol";

/// @title Dawn node operator manager contract
/// @author Ray Lv
/// @notice Dawn manage their node operators by this contract
contract DepositNodeManager is IDepositNodeManager, DawnBase {
    uint256 internal constant DEPOSIT_BASE = 32 ether;
    bytes32 internal constant NEXT_VALIDATOR_ID = keccak256("DepositNodeManager.NEXT_VALIDATOR_ID");
    bytes32 internal constant AVAILABLE_VALIDATOR_COUNT = keccak256("DepositNodeManager.AVAILABLE_VALIDATOR_COUNT");

    constructor(IDawnStorageInterface dawnStorage) DawnBase(dawnStorage) {}

    /// @notice Register an node operator and deploy a node operator contract for request address
    /// @return Deployed node operator contract address
    function registerNodeOperator() external returns (address) {
        bytes32 operatorStorageKey = _getStorageKeyByOperatorAddress(msg.sender);
        require(getAddress(operatorStorageKey) == address(0), "Operator already exist!");
        DepositNodeOperator nodeAddress = new DepositNodeOperator(msg.sender, _dawnStorage);
        setAddress(operatorStorageKey, address(nodeAddress));
        setBool(operatorStorageKey, true);
        emit NodeOperatorRegistered(address(nodeAddress));
        return address(nodeAddress);
    }

    /// @notice Get the node operator contract address
    function getNodeOperator(address operator) public view returns (address nodeAddress, bool isActive) {
        bytes32 operatorStorageKey = _getStorageKeyByOperatorAddress(operator);
        nodeAddress = getAddress(operatorStorageKey);
        isActive = getBool(operatorStorageKey);
    }

    function getAvailableValidatorsCount() public view returns (uint256) {
        return getUint(AVAILABLE_VALIDATOR_COUNT);
    }

    function distributeFunds(
        uint256[] calldata validatorIds
    ) external payable onlyLatestContract("DawnDeposit", msg.sender) {
        uint256 depositCount = validatorIds.length;
        require(
            msg.value >= depositCount * (DEPOSIT_BASE - _getMinOperatorDepositAmount()),
            "Not enough distributed funds!"
        );
        require(depositCount <= getAvailableValidatorsCount(), "Not enough available validators!");
        /// TODO deposit
    }

    function registerValidators(address operator, uint256 count) external returns (uint256) {
        (address nodeAddress, bool isActive) = getNodeOperator(operator);
        require(msg.sender == nodeAddress, "Only node operator can register validators!");
        require(isActive, "Node operator is inactive!");
        IDawnDeposit(getContractAddressUnsafe("DawnDeposit")).mintSharesForNodeOperator(
            msg.sender,
            _getMinOperatorDepositAmount() * count
        );
        uint256 startIndex = getUint(NEXT_VALIDATOR_ID);
        bytes32 validatorStorageKey;
        for (uint i = 0; i < count; ++i) {
            validatorStorageKey = _getStorageKeyByValidatorIndex(startIndex + i);
            setAddress(validatorStorageKey, msg.sender);
            setUint(validatorStorageKey, uint(ValidatorStatus.WAITING_ACTIVATED));
        }
        setUint(NEXT_VALIDATOR_ID, startIndex + count);
        setUint(AVAILABLE_VALIDATOR_COUNT, getUint(AVAILABLE_VALIDATOR_COUNT) + count);
        return startIndex;
    }

    function getNodeValidator(
        uint256 validatorIndex
    ) external view returns (address nodeAddress, ValidatorStatus status) {
        bytes32 validatorStorageKey = _getStorageKeyByValidatorIndex(validatorIndex);
        nodeAddress = getAddress(validatorStorageKey);
        status = ValidatorStatus(getUint(validatorStorageKey));
    }

    function _getMinOperatorDepositAmount() internal view returns (uint256) {
        // TODO
        return 2 ether;
    }

    function _getStorageKeyByOperatorAddress(address operator) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeManager.operator", operator));
    }

    function _getStorageKeyByValidatorIndex(uint256 index) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeManager.validatorIndex", index));
    }
}
