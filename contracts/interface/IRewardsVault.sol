// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

interface IRewardsVault {
    function withdrawRewards(uint256 availableRewards) external;
}
