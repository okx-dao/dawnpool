// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

/**
 * @title Node operator contract
 * @author Ray
 * @notice Node operator add his validator pubkeys through his node operator contract
 * @dev Node operator needs to stake specified amount of ETH to add a validator through this contract
 * The staked ETH will be transferred to dawn deposit pool and the returned pETH locked in this contract
 * It will be claimable if the operator exit his validators
 * However, the "overflow" part of shares can be claimed with validator rewards
 */
interface IDepositNodeOperator {

    event NodeOperatorStakingRewardsClaimed(address indexed claimer, address indexed withdrawAddress, uint256 amount);

    /**
     * @notice Get node operator address
     * @return Node operator address
     */
    function getOperator() external view returns (address);

    /**
     * @notice Add stakes for operator, and any account can do this
     * @return Minted pETH amount
     */
    function addStakes() external payable returns (uint256);

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
    ) external payable returns (uint256 startIndex, uint256 count);

    /**
     * @notice Get active validators of node operator, includes all validators not exit
     * @return Active validators count
     */
    function getActiveValidatorsCount() external view returns (uint256);

    /**
     * @notice Get validating validators of node operator, only VALIDATING
     * @return Active validators count
     */
    function getValidatingValidatorsCount() external view returns (uint256);

    /**
     * @notice Activate a validator
     * @param index Validator index
     * @param pubkey Validator public key
     */
    function activateValidator(uint256 index, bytes calldata pubkey) external;

    /// @notice Claim the operator staking and node rewards
    function claimRewards() external;

    /**
     * @notice Change validators status before operator exit his validators
     * @param indexes Validators indexes will exit
     * @dev Node operator can exit his validators anytime, but need to change contract validator status first
     */
    function voluntaryExitValidators(uint256[] calldata indexes) external;
}
