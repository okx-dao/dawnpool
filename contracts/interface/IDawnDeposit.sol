// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

interface IDawnDeposit {

    event Stake(address indexed staker, uint256 ethAmount);

    // user stake ETH to DawnPool returns pETH
    function stake() external payable returns (uint256);
    // user unstake pETH from DawnPool returns ETH
    function unstake(uint pEthAmount) external returns (uint256);

    // receive ETH rewards from RewardsVault
    function receiveRewards() external;
    // distribute ETH rewards to NodeOperators、DawnVault、DawnTreasury
    function distributeRewards(uint256 rewards) internal;
    // transfer pETH as rewards to DawnVault
    function transferToVault(uint256 rewards) internal;
    // transfer pETH as rewards to DawnTreasury
    function transferToTreasury(uint256 rewards) internal;
    // distribute pETH as rewards to NodeOperators
    function distributeNodeOperatorRewards(uint256 rewards) internal;

    // oracle report balance of validators
    function oracleReport() external;

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