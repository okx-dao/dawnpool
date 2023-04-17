// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

/// @title Dawn node operator manager interface
/// @author Ray
interface IDepositNodeManager {
    /**
    * @notice Emit when node operator registered
    * @param operator Address of node operator
    * @param nodeAddress Contract address of node operator
    */
    event NodeOperatorRegistered(address indexed operator, address indexed nodeAddress);
    /**
    * @notice Emit when validators registered
    * @param nodeAddress Contract address of node operator
    * @param startIndex The first index of validators registered
    * @param count Count of validators registered
    */
    event NodeValidatorsRegistered(address indexed nodeAddress, uint256 startIndex, uint256 count);

    /**
    * @notice Validator status, should be WAITING_ACTIVATED -> ACTIVE -> EXITING -> EXITED
    * Get SLASHING status when operator do sth bad
    */
    enum ValidatorStatus {
        NOT_EXIST,
        WAITING_ACTIVATED,
        ACTIVE,
        EXITING,
        SLASHING,
        EXITED
    }

    /**
    * @notice Register an node operator and deploy a node operator contract for request address
    * @return Deployed node operator contract address, and set it active
    */
    function registerNodeOperator() external returns (address);

    /**
    * @notice Get the node operator contract address and status
    * @param operator Node operator address
    * @return nodeAddress Node operator contract address
    * @return isActive Whether the operator is active
    */
    function getNodeOperator(address operator) external view returns (address nodeAddress, bool isActive);

    /**
    * @notice Get available validator pubkeys count
    * @return Available validator pubkeys count
    * Only validators signed pre-exit msg can really get funds and be activated
    */
    function getAvailableValidatorsCount() external view returns (uint256);

    /**
    * @notice Node operators register validators and get operator index in return
    * @dev Function called when operators add pubkeys
    * @param operator Node operator address, for access control
    * @param count Node operator count request to register
    * @return The first index of validators registered
    */
    function registerValidators(address operator, uint256 count) external returns (uint256);

    /**
    * @notice Get contract and status of validator by index
    * @param validatorIndex Index of validator
    * @return nodeAddress Node operator contract address the validator belongs to
    * @return status Validator status
    */
    function getNodeValidator(uint256 validatorIndex) external view returns (address nodeAddress, ValidatorStatus status);

    /// @notice Set minimum deposit amount, may be changed by DAO
    function setMinOperatorStakingAmount(uint256 minAmount) external;

    /// @notice Get minimum deposit amount, may be changed by DAO
    function getMinOperatorStakingAmount() external view returns(uint256);
}
