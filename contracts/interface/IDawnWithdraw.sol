// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

interface IDawnWithdraw {
    event LogWithdrawalRequested(
        uint256 indexed requestId,
        address indexed owner,
        uint256 pEthAmount,
        uint256 maxClaimableEtherAmount
    );

    error TooMuchEtherToLocked(uint256 sent, uint256 maxExpected);

    function requestWithdraw(uint256 pEthAmount) external returns (uint256 requestId);

    function fulfillment() external;

    function claimEther(uint256 requestId, address recipient) external;
}