// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDawnDeposit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

struct PermitInput {
    uint256 value;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

abstract contract DawnWithdrawStorageLayout {
    mapping(uint256 => WithdrawRequest) public withdrawRequestQueue;
    mapping(uint256 => CheckPoint) public checkPoints;
}
