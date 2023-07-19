// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../core/DawnWithdrawStorageLayout.sol";

interface IDawnWithdraw {
    event LogWithdrawalRequested(
        uint256 indexed requestId,
        address indexed owner,
        uint256 pEthAmount,
        uint256 maxClaimableEtherAmount
    );
    event LogClaimed(address owner, uint256 ethAmount);
    event LogFulfillment(
        uint256 ethValue,
        uint256 lastRequestIdToBeFulfilled,
        uint256 checkpointIndex
    );

    error TooMuchEtherToLocked(uint256 sent, uint256 maxExpected);
    error AlreadyClaimed(uint256 requestId);
    error NotWithdrawOwner(uint256 requestId, address owner, address sender);

    function requestWithdrawWithPermit(uint256 pEthAmount, PermitInput calldata _permit) external returns (uint256 requestId);
    function requestWithdraw(uint256 pEthAmount) external returns (uint256 requestId);

    function fulfillment(uint256 lastRequestIdToBeFulfilled) external payable;

    function claimEther(uint256 requestId) external;

    function checkFulfillment(uint256 lastRequestIdToBeFulfilled, uint256 ethAmountToLock) external view;

    function getUnfulfilledWithdrawRequestQueue() external view returns (WithdrawRequest[] memory unfulfilledWithdrawRequestQueue);
    function getWithdrawQueueStat() external view returns (uint256 lastFulfillmentRequestId, uint256 lastRequestId, uint256 lastCheckpointIndex);

    function getUnfulfilledTotalPEth() external view returns (uint256);
    function getUnfulfilledTotalEth() external view returns (uint256);
}