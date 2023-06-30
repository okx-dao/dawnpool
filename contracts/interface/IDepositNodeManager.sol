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
     * @param index Validator index
     * @param operator Operator address
     * @param pubkey Validator public key
     */
    event SigningKeyAdded(uint256 indexed index, address indexed operator, bytes pubkey);

    /**
     * @notice Emit when validator activated
     * @param index Validator index
     * @param operator Operator address
     * @param pubkey Validator public key
     */
    event SigningKeyActivated(uint256 indexed index, address indexed operator, bytes pubkey);

    /**
     * @notice Emit when validator request to exit
     * @param index Validator index
     * @param operator Operator address
     * @param pubkey Validator public key
     */
    event SigningKeyExit(uint256 indexed index, address indexed operator, bytes pubkey);

    /**
     * @notice Emit when validator is set unsafe
     * @param index Validator index
     * @param operator Operator address
     * @param pubkey Validator public key
     * @param nodeAddress The node address to get slashed
     * @param slashedPethAmount PETH amount to get slashed
     */
    event SigningKeyUnsafe(uint256 indexed index, address indexed operator, bytes pubkey, address nodeAddress, uint256 slashedPethAmount);

    /**
     * @notice Emit when validator is set unsafe
     * @param index Validator index
     * @param operator Operator address
     * @param pubkey Validator public key
     * @param nodeAddress The node address to get slashed
     * @param slashedPethAmount PETH amount to get slashed
     */
    event SigningKeySlashing(uint256 indexed index, address indexed operator, bytes pubkey, address nodeAddress, uint256 slashedPethAmount);

    event SigningKeyPunished(uint256 indexed index, address indexed operator, bytes pubkey, address nodeAddress, uint256 slashedPethAmount, bytes reason);

    /**
     * @notice Emit when receive node operator rewards
     * @param pethAmount Received PETH amount
     * @param rewardsAddedPerValidator Rewards amount a validator can be distributed this time
     */
    event NodeOperatorRewardsReceived(uint256 pethAmount, uint256 rewardsAddedPerValidator);

    /**
     * @notice Emit when distribute Node rewards(commission) to the node operator
     * @param operator Operator address
     * @param claimer Address who call this function
     * @param withdrawAddress Node rewards distributed to
     * @param pethAmount Node rewards amount distributed to the operator and claimed
     */
    event NodeOperatorNodeRewardsClaimed(address indexed operator, address indexed claimer, address indexed withdrawAddress, uint256 pethAmount);

    /**
     * @notice Validator status, should be WAITING_ACTIVATED -> VALIDATING -> EXIT
     * Get SLASHING status when operator do sth bad
     */
    enum ValidatorStatus {
        NOT_EXIST,
        WAITING_ACTIVATED,
        VALIDATING,
        EXIT,
        SLASHING,
//        EXITED,
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
     * @param index The index of the validator
     * @return operator Operator address the validator belongs to
     * @return pubkey Public key
     * @return status Validator status
     */
    function getNodeValidator(uint256 index) external view returns (address operator, bytes memory pubkey, ValidatorStatus status);

    /**
     * @notice Get contract and status of validator by pubkey
     * @param pubkey The public key of the validator
     * @return index The index of the validator
     * @return operator Operator address the validator belongs to
     * @return status Validator status
     */
    function getNodeValidator(bytes calldata pubkey) external view returns (uint256 index, address operator, ValidatorStatus status);

    /**
     * @notice Get contract and status of validator by index
     * @param startIndex Start index of validators request to get
     * @param amount Amount of validators request to get, 0 means all
     * @return operators Operators addresses the validators belong to
     * @return pubkeys Public keys
     * @return statuses Validator statuses
     */
    function getNodeValidators(uint256 startIndex, uint256 amount) external view returns (address[] memory operators, bytes[] memory pubkeys, ValidatorStatus[] memory statuses);

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

    /**
     * @notice Set validator unsafe, the validator which was deposited
     * and was set wrong withdraw credential should be slashed by Oracle
     * @param index Validator index
     * @param slashedPethAmount PETH amount to be slashed
     */
    function setValidatorUnsafe(uint256 index, uint256 slashedPethAmount) external;

    /**
     * @notice Distribute node operator rewards PETH
     * @param pethAmount distributed amount
     */
    function distributeNodeOperatorRewards(uint256 pethAmount) external;

    /// @notice Get the operator withdraw address
    function getWithdrawAddress(address operator) external view returns (address);

    /// @notice Set the operator withdraw address
    function setWithdrawAddress(address withdrawAddress) external;

    /// @notice Get the operator claimable node rewards(commission)
    function getClaimableNodeRewards(address operator) external view returns (uint256);

    /// @notice Claim the operator node rewards(commission)
    function claimNodeRewards(address operator) external;

    /**
     * @notice Change validators status before exit
     * @param count Validators count to change status
     * @return indexes Exit validators indexes
     * @dev Validators should exit firstly who joined at the earliest(least index)
     */
    function updateValidatorsExit(uint256 count) external returns (uint256[] memory indexes);

    /**
     * @notice Change validators status before operator exit his validators
     * @param operator Node operator address
     * @param indexes Validators indexes will exit
     * @dev Node operator can exit his validators anytime, but need to change contract validator status first
     */
    function operatorRequestToExitValidators(address operator, uint256[] calldata indexes) external;

    /**
     * @notice Set validators status exit
     * @param index Validator index is exit
     */
    function setValidatorExit(uint256 index) external;

    function setValidatorSlashing(uint256 index, uint256 slashedPethAmount, bool slashFinished) external;

    function punishOneValidator(uint256 index, uint256 slashedPethAmount, bytes calldata reason) external;
}
