// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

interface IDepositNodeManager {
    event NodeOperatorRegistered(address indexed nodeAddress);

    enum ValidatorStatus {
        NOT_EXIST,
        WAITING_ACTIVATED,
        ACTIVE,
        EXITING,
        SLASHING,
        EXITED
    }

    /// @dev Node operator register interface
    function registerNodeOperator() external returns (address);

    /// @dev Node operator query interface
    function getNodeOperator(address operator) external view returns (address nodeAddress, bool isActive);

    /// @dev Get current waiting activated validators count
    function getAvailableValidatorsCount() external view returns (uint256);

    /// @dev Distribute funds to operators to activate
    function distributeFunds(uint256[] calldata validatorIds) external payable;

    /// @dev Node operator register validators when add pubkeys
    function registerValidators(address operator, uint256 count) external returns (uint256 startIndex);

    /// @dev Get node validator by index
    function getNodeValidator(
        uint256 validatorIndex
    ) external view returns (address nodeAddress, ValidatorStatus status);
}
