// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IRewardsVault.sol";
import "../base/DawnBase.sol";

interface IDawnDeposit {
    // receive ETH rewards from RewardsVault
    function receiveRewards() external payable;
}

contract RewardsVault is DawnBase, IRewardsVault {

    constructor(IDawnStorageInterface _dawnStorageAddress) DawnBase(_dawnStorageAddress) {

    }

    function withdrawRewards(uint256 availableRewards) external {
        require(msg.sender == getContractAddress("DawnDeposit"), "only call by DawnDeposit");
        require(address(this).balance >= availableRewards, "insufficient balance");
        IDawnDeposit(getContractAddress("DawnDeposit")).receiveRewards{value: availableRewards}();
    }
}