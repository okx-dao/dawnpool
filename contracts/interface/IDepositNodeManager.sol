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
     * @notice Emit when node operator withdraw address is set
     * @param operator Address of node operator
     * @param withdrawAddress Withdraw address
     */
    event WithdrawAddressSet(address indexed operator, address withdrawAddress);

    /**
     * @notice Emit when staking amount is set
     * @param amount Current amount set
     */
    event MinOperatorStakingAmountSet(address indexed from, uint256 amount);

    /**
     * @notice Emit when validator pubkey and signature added
     * @param validatorId Validator index
     * @param operator Operator address
     * @param pubkey Validator public key
     */
    event SigningKeyAdded(uint256 indexed validatorId, address indexed operator, bytes indexed pubkey);

    /**
     * @notice Emit when validator activated
     * @param validatorId Validator index
     * @param operator Operator address
     * @param pubkey Validator public key
     */
    event SigningKeyActivated(uint256 indexed validatorId, address indexed operator, bytes indexed pubkey);

    /**
     * @notice Emit when receive node operator rewards
     * @param pethAmount Received PETH amount
     * @param rewardsPerValidator Rewards amount a validator can be distributed
     */
    event NodeOperatorRewardsReceived(uint256 pethAmount, uint256 rewardsPerValidator);

    /**
     * @notice Emit when distribute rewards to the node operator
     * @param operator Operator address
     * @param pethAmount Rewards amount distributed to the operator
     * @param to Rewards distributed to, generally is operator's node contract
     */
    event NodeOperatorRewardsDistributed(address indexed operator, uint256 pethAmount, address to);

    /**
     * @notice Validator status, should be WAITING_ACTIVATED -> VALIDATING -> EXITING -> EXITED
     * Get SLASHING status when operator do sth bad
     */
    enum ValidatorStatus {
        NOT_EXIST,
        WAITING_ACTIVATED,
        VALIDATING,
        EXITING,
        SLASHING,
        EXITED,
        UNSAFE
    }

    /**
     * @notice Register an node operator and deploy a node operator contract for request address
     * @return Deployed node operator contract address, and set it active
     */
    function registerNodeOperator(address withdrawAddress) external returns (address);

    /**
     * @notice Get the node operator contract address and status
     * @param operator Node operator address
     * @return nodeAddress Node operator contract address
     * @return isActive Whether the operator is active
     */
    function getNodeOperator(address operator) external view returns (address nodeAddress, bool isActive);

    /**
     * @notice Node operators register validators and get operator index in return
     * @dev Function called when operators add pubkeys
     * @param operator Node operator address, for access control
     * @param pubkey public key
     * @return The index of validator registered
     */
    function registerValidator(address operator, bytes calldata pubkey) external returns (uint256);

    /**
     * @notice Get contract and status of validator by index
     * @param index Index of validator
     * @return operator Operator address the validator belongs to
     * @return pubkey Public key
     * @return status Validator status
     */
    function getNodeValidator(uint256 index) external view returns (address operator, bytes memory pubkey, ValidatorStatus status);

    /// @notice Set minimum deposit amount, may be changed by DAO
    function setMinOperatorStakingAmount(uint256 minAmount) external;

    /// @notice Get minimum deposit amount, may be changed by DAO
    function getMinOperatorStakingAmount() external view returns (uint256);

    /**
     * @notice Activate validators by index
     * @param indexes Index array of validators to be activated
     */
    function activateValidators(uint256[] calldata indexes) external;

    /// @notice Get total validators count including all status
    function getTotalValidatorsCount() external view returns (uint256);

    /// @notice Get total activated validators count only including VALIDATING status
    function getTotalActivatedValidatorsCount() external view returns (uint256);

    function setValidatorUnsafe(uint256 index, uint256 slashAmount) external;

    /**
     * @notice Distribute node operator rewards PETH
     * @param pethAmount distributed amount
     */
    function distributeNodeOperatorRewards(uint256 pethAmount) external;

    /// @notice Get the operator withdraw address
    function getWithdrawAddress(address operator) external view returns (address);

    /// @notice Set the operator withdraw address
    function setWithdrawAddress(address withdrawAddress) external;
}
