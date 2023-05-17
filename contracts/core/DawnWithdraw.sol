// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "./DawnDeposit.sol";
import "../interface/IDawnWithdraw.sol";

contract DawnWithdraw is IDawnWithdraw {

    struct WithdrawRequest {
        address owner;
        uint256 cumulativePEth;
        uint256 maxCumulativeClaimableEther;
        uint256 createdTime;
        bool claimed;
    }

    IDawnDeposit public immutable dawnDeposit;
    IERC20 public immutable pEthToken;

    uint256 lastFulfillmentRequestId;
    uint256 lastRequestId;

    mapping(uint256 => WithdrawRequest) withdrawRequestQueue;



    function requestWithdraw(uint256 pEthAmount) external returns (uint256 requestId) {
        // 请求赎回的pEthAmount不能为0
        require(pEthAmount > 0, "Zero pEth");
        // 判断msg.sender 是否有足够的 PEth
        require(pEthToken.balanceOf(msg.sender) >= pEthAmount, "PEth not enough");

        // maxClaimableEther
        uint256 maxClaimableEther = dawnDeposit.getEtherByPEth(pEthAmount);
        assert(maxClaimableEther != 0);

        WithdrawRequest memory lastWithdrawRequest = withdrawRequestQueue[lastRequestId];

        // 创建WithdrawRequest并存到队列中
        WithdrawRequest memory withdrawRequest = WithdrawRequest(
            msg.sender,
            lastWithdrawRequest.cumulativePEth + pEthAmount,
            lastWithdrawRequest.maxCumulativeClaimableEther + maxClaimableEther,
            block.timestamp,
            false
        );
        requestId = ++lastRequestId;
        withdrawRequestQueue[requestId] = withdrawRequest;

        // 触发创建赎回请求的事件
        emit LogWithdrawalRequested(requestId, msg.sender, pEthAmount, maxClaimableEtherAmount);
    }

    function fulfillment(uint256 lastRequestIdToBeFulfilled) external payable {
        // onlyDawnDeposit

        require(lastRequestIdToBeFulfilled <= lastRequestId, "Invalid requestId");
        require(lastRequestIdToBeFulfilled > lastFulfillmentRequestId, "Already fulfillment");

        WithdrawRequest memory startRequest = withdrawRequestQueue[lastFulfillmentRequestId + 1];
        WithdrawRequest memory endRequest = withdrawRequestQueue[lastRequestIdToBeFulfilled];

        // 锁定的ether不能超过创建赎回请求时能够赎回的数量，即创建赎回请求时开始，不在产生收益
        if (msg.value > endRequest.maxCumulativeClaimableEther - startRequest.maxCumulativeClaimableEther) {
            revert TooMuchEtherToLocked(msg.value, endRequest.maxCumulativeClaimableEther - startRequest.maxCumulativeClaimableEther);
        }

        // todo



    }

    function claimEther(uint256 requestId, address recipient) external {

    }


}