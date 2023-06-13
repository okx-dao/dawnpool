// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDawnDeposit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract DawnWithdrawStorageLayout {
    struct WithdrawRequest {
        address owner;
        uint256 cumulativePEth;
        uint256 maxCumulativeClaimableEther;
        uint256 createdTime;
        bool claimed;
    }

    struct CheckPoint {
        uint256 totalEther;
        uint256 totalPEth;
        uint256 endRequestId;
    }

    uint256 lastFulfillmentRequestId;
    uint256 lastRequestId;
    WithdrawRequest[] withdrawRequestQueue;
    uint256 lastCheckpointIndex;
    CheckPoint[] checkPoints;
}