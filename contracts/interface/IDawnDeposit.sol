// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

interface IDawnDeposit {

    event Stake(address indexed staker, uint256 ethAmount);

    // user stake ETH to DawnPool returns pETH
    function stake() external payable returns (uint256);
    // user unstake pETH from DawnPool returns ETH
    function unstake(uint pEthAmount) external returns (uint256);

    // receive ETH rewards from RewardsVault
    function receiveRewards() external payable;
    // distribute pETH rewards to NodeOperators、DawnInsurance、DawnTreasury
    function distributeRewards(uint256 rewardsPEth) internal;
    // transfer pETH as rewards to DawnInsurance
    function transferToInsurance(uint256 rewardsPEth) internal;
    // transfer pETH as rewards to DawnTreasury
    function transferToTreasury(uint256 rewardsPEth) internal;
    // distribute pETH as rewards to NodeOperators
    function distributeNodeOperatorRewards(uint256 rewardsPEth) internal;

    // handle oracle report
    function handleOracleReport(uint256 beaconValidators, uint256 beaconBalance, uint256 availableRewards) external;

    // receive pETH from Treasury, and burn pETH
    function receiveFromTreasury(uint256 pEthAmount) external;

    // deposit 32 ETH to activate validator
    function activateValidator() external;

    // calculate the amount of pETH backing an amount of ETH
    function getEtherByPEth(uint256 pEthAmount) public view returns (uint256);
    // calculate the amount of ETH backing an amount of pETH
    function getPEthByEther(uint256 ethAmount) public view returns (uint256);
    // get DawnPool protocol total value locked
    function getTotalPooledEther() public view returns (uint256);
}