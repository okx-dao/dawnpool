// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

interface IRewardsVault {
    event LogETHReceived(uint256 amount);

    function withdrawRewards(uint256 availableRewards) external;
}
