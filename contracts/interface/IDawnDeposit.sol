// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

interface IDawnDeposit {

    event LogStake(address indexed staker, uint256 ethAmount);
    event LogReceiveRewards(uint256 ethAmount);

    // user stake ETH to DawnPool returns pETH
    function stake() external payable returns (uint256);
    // user unstake pETH from DawnPool returns ETH
    function unstake(uint pEthAmount) external returns (uint256);
    // receive ETH rewards from RewardsVault
    function receiveRewards() external payable;
    // handle oracle report
    function handleOracleReport(uint256 beaconValidators, uint256 beaconBalance, uint256 availableRewards) external;
    // receive pETH from Insurance, and burn
    function receiveFromInsurance(uint256 pEthAmount) external;
    // deposit 32 ETH to activate validator
    function activateValidator() external;
}