// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDawnWithdraw.sol";
import "../base/DawnBase.sol";
import "./DawnWithdrawStorageLayout.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interface/IDawnDeposit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DawnWithdraw is IDawnWithdraw, DawnBase, DawnWithdrawStorageLayout {
    using SafeMath for uint256;


    bytes32 internal constant _LAST_FULFILLMENT_REQUEST_ID_KEY = keccak256("dawnWithdraw.lastFulfillmentRequestId");
    bytes32 internal constant _LAST_REQUEST_ID_KEY = keccak256("dawnWithdraw.lastRequestId");
    bytes32 internal constant _LAST_CHECKPOINT_INDEX_KEY = keccak256("dawnWithdraw.lastCheckpointIndex");

    // ***************** contract name *****************
    string internal constant _DAWN_DEPOSIT_CONTRACT_NAME = "DawnDeposit";

    error InvalidRequestIdToBeFulfilled(uint256 preLastFulfilledRequestId, uint256 lastRequestId, uint256 requestId);
    error EthNotExpect(uint256 expectEth, uint256 ethAmountToLock);


    //    constructor
    constructor(IDawnStorageInterface dawnStorageAddress) DawnBase(dawnStorageAddress) { }

    // user call
    function requestWithdraw(uint256 pEthAmount) external returns (uint256 requestId) {
        // 请求赎回的pEthAmount不能为0
        require(pEthAmount > 0, "Zero pEth");
        // 判断msg.sender 是否有足够的 PEth
        require(IERC20(_getContractAddress(_DAWN_DEPOSIT_CONTRACT_NAME)).balanceOf(msg.sender) >= pEthAmount, "PEth not enough");

        // maxClaimableEther
        uint256 maxClaimableEther = IDawnDeposit(_getContractAddress(_DAWN_DEPOSIT_CONTRACT_NAME)).getEtherByPEth(pEthAmount);
        assert(maxClaimableEther != 0);

        uint256 lastRequestId = _getUint(_LAST_REQUEST_ID_KEY);
        WithdrawRequest memory lastWithdrawRequest = withdrawRequestQueue[lastRequestId];

        // 创建WithdrawRequest并存到队列中
        WithdrawRequest memory withdrawRequest = WithdrawRequest(
            msg.sender,
            lastWithdrawRequest.cumulativePEth + pEthAmount,
            lastWithdrawRequest.maxCumulativeClaimableEther + maxClaimableEther,
            block.timestamp,
            false
        );
        withdrawRequestQueue[lastRequestId + 1] = withdrawRequest;

        // update lastRequestId
        _addUint(_LAST_REQUEST_ID_KEY, 1);

        // 触发创建赎回请求的事件
        emit LogWithdrawalRequested(requestId, msg.sender, pEthAmount, maxClaimableEther);
    }

    // DawnPool
    function fulfillment(uint256 lastRequestIdToBeFulfilled) external payable onlyAllowDawnDeposit {
        uint256 lastRequestId = _getUint(_LAST_REQUEST_ID_KEY);
        uint256 lastFulfillmentRequestId = _getUint(_LAST_FULFILLMENT_REQUEST_ID_KEY);
        require(lastRequestIdToBeFulfilled <= lastRequestId, "Invalid requestId");
        require(lastRequestIdToBeFulfilled > lastFulfillmentRequestId, "Already fulfillment");

        // (startRequest, endRequest]
        WithdrawRequest memory startRequest = withdrawRequestQueue[lastFulfillmentRequestId];
        WithdrawRequest memory endRequest = withdrawRequestQueue[lastRequestIdToBeFulfilled];

        // 锁定的ether不能超过创建赎回请求时能够赎回的数量，即创建赎回请求时开始，不在产生收益
        if (msg.value > endRequest.maxCumulativeClaimableEther - startRequest.maxCumulativeClaimableEther) {
            revert TooMuchEtherToLocked(msg.value, endRequest.maxCumulativeClaimableEther - startRequest.maxCumulativeClaimableEther);
        }

        uint256 lastCheckpointIndex = _getUint(_LAST_CHECKPOINT_INDEX_KEY);
        // add checkpoint
        checkPoints[lastCheckpointIndex] = CheckPoint(
                    IDawnDeposit(_getContractAddress(_DAWN_DEPOSIT_CONTRACT_NAME)).getTotalPooledEther(),
                    IERC20(_getContractAddress(_DAWN_DEPOSIT_CONTRACT_NAME)).totalSupply(),
                    lastRequestIdToBeFulfilled
        );

        // 更新
        _addUint(_LAST_CHECKPOINT_INDEX_KEY, 1);
        _setUint(_LAST_FULFILLMENT_REQUEST_ID_KEY, lastRequestIdToBeFulfilled);

        emit LogFulfillment(msg.value, lastRequestIdToBeFulfilled, lastCheckpointIndex);
    }


    function checkFulfillment(uint256 lastRequestIdToBeFulfilled, uint256 ethAmountToLock) public view {
        uint256 preLastFulfillmentRequestId = _getUint(_LAST_FULFILLMENT_REQUEST_ID_KEY);
        uint256 lastRequestId = _getUint(_LAST_REQUEST_ID_KEY);
        if (lastRequestIdToBeFulfilled <= lastRequestId || lastRequestIdToBeFulfilled > preLastFulfillmentRequestId) {
            revert InvalidRequestIdToBeFulfilled(preLastFulfillmentRequestId, lastRequestId, lastRequestIdToBeFulfilled);
        }

        uint256 expectEth = 0;

        for (uint256 i = preLastFulfillmentRequestId; i <= lastRequestIdToBeFulfilled; i++) {
            expectEth += Math.min(
                withdrawRequestQueue[i].maxCumulativeClaimableEther - withdrawRequestQueue[i - 1].maxCumulativeClaimableEther,
                IDawnDeposit(_getContractAddress(_DAWN_DEPOSIT_CONTRACT_NAME)).getEtherByPEth(withdrawRequestQueue[i].cumulativePEth - withdrawRequestQueue[i - 1].cumulativePEth)
            );
        }

        if (expectEth != ethAmountToLock) revert EthNotExpect(expectEth, ethAmountToLock);
    }

    // user
    function claimEther(uint256 requestId) external {
        // 判断requestId是否在合法的范围内
        require(requestId > 0, "Zero withdraw requestId");
        // 判断requestId是否已经处于fulfillment状态
        require(requestId <= _getUint(_LAST_FULFILLMENT_REQUEST_ID_KEY), "Not fulfillment");

        WithdrawRequest memory withdrawRequest = withdrawRequestQueue[requestId];
        // 判断是否已经被claim过
        if (withdrawRequest.claimed) {
            revert AlreadyClaimed(requestId);
        }
        // 判断是否本人提取
        if (withdrawRequest.owner != msg.sender) {
            revert NotWithdrawOwner(requestId, withdrawRequest.owner, msg.sender);
        }

        // update claim status
        withdrawRequest.claimed = true;

        WithdrawRequest memory preWithdrawRequest = withdrawRequestQueue[requestId - 1];
        // requestWithdraw rate
        uint256 ethAmount = withdrawRequest.maxCumulativeClaimableEther - preWithdrawRequest.maxCumulativeClaimableEther;
        uint256 pethAmount = withdrawRequest.cumulativePEth - preWithdrawRequest.cumulativePEth;
        // 根据pethAmount以及fulfillment阶段确定的requestId所属的CheckPoint时汇率，计算出最多能兑换 x Ether
        uint256 checkPointIndex = _findCheckPointByRequestId(requestId, 0, _getUint(_LAST_CHECKPOINT_INDEX_KEY));
        ethAmount = Math.min(ethAmount, _getMaxEtherByCheckPoint(pethAmount, checkPoints[checkPointIndex]));

        // transfer ethAmount ether to msg.sender
        payable(msg.sender).transfer(ethAmount);
        // emit
        emit LogClaimed(msg.sender, ethAmount);
    }

    // 获取未完成的赎回请求队列(返回的数组index=0的WithdrawRequest是fulfilled)
    function getUnfulfilledWithdrawRequestQueue() public view returns (WithdrawRequest[] memory unfulfilledWithdrawRequestQueue) {
        uint256 lastFulfillmentRequestId = _getUint(_LAST_FULFILLMENT_REQUEST_ID_KEY);
        uint256 length = withdrawRequestQueue.length - lastFulfillmentRequestId;
        unfulfilledWithdrawRequestQueue = new WithdrawRequest[](length);

        for (uint256 i = lastFulfillmentRequestId; i < withdrawRequestQueue.length; i++) {
            unfulfilledWithdrawRequestQueue[i - lastFulfillmentRequestId] = withdrawRequestQueue[i];
        }
    }

    function getWithdrawRequestQueue() public view returns (WithdrawRequest[] memory) {
        return withdrawRequestQueue;
    }

    function getCheckPoints() public view returns (CheckPoint[] memory) {
        return checkPoints;
    }

    function getWithdrawQueueStat() public view returns (uint256 lastFulfillmentRequestId, uint256 lastRequestId, uint256 lastCheckpointIndex) {
        lastFulfillmentRequestId = _getUint(_LAST_FULFILLMENT_REQUEST_ID_KEY);
        lastRequestId = _getUint(_LAST_REQUEST_ID_KEY);
        lastCheckpointIndex = _getUint(_LAST_CHECKPOINT_INDEX_KEY);
    }

    function getUnfulfilledTotalPEth() public view returns (uint256) {
        uint256 lastFulfillmentRequestId = _getUint(_LAST_FULFILLMENT_REQUEST_ID_KEY);
        uint256 lastRequestId = _getUint(_LAST_REQUEST_ID_KEY);
        if (lastFulfillmentRequestId == lastRequestId) {
            return 0;
        }
        return withdrawRequestQueue[lastRequestId].cumulativePEth - withdrawRequestQueue[lastFulfillmentRequestId].cumulativePEth;
    }

    function getUnfulfilledTotalEth() public view returns (uint256) {
        uint256 lastFulfillmentRequestId = _getUint(_LAST_FULFILLMENT_REQUEST_ID_KEY);
        uint256 lastRequestId = _getUint(_LAST_REQUEST_ID_KEY);
        if (lastFulfillmentRequestId == lastRequestId) {
            return 0;
        }
        return withdrawRequestQueue[lastRequestId].maxCumulativeClaimableEther - withdrawRequestQueue[lastFulfillmentRequestId].maxCumulativeClaimableEther;
    }

    // [start, end)
    function _findCheckPointByRequestId(uint256 requestId, uint256 start, uint256 end) internal view returns(uint256 checkPointIndex) {
        require(requestId <= _getUint(_LAST_FULFILLMENT_REQUEST_ID_KEY), "Not fulfillment");
        checkPointIndex = 0;
        uint256 mid = start + (end - start) / 2;
        uint256 midFrom;
        while (start < end) {
            if (requestId > checkPoints[mid].endRequestId) {
                start = mid + 1;
            } else {
                if (mid == 0) midFrom = 0;
                midFrom = checkPoints[mid - 1].endRequestId;
                if (requestId > midFrom && requestId <= checkPoints[mid].endRequestId) {
                    checkPointIndex = mid;
                    break ;
                }
                end = mid - 1;
            }
        }
    }

    function _getMaxEtherByCheckPoint(uint256 pethAmount, CheckPoint memory checkPoint) internal pure returns(uint256 ethAmount) {
        ethAmount = pethAmount.mul(checkPoint.totalEther).div(checkPoint.totalPEth);
    }

    modifier onlyAllowDawnDeposit() {
        require(msg.sender == _getContractAddress(_DAWN_DEPOSIT_CONTRACT_NAME), "Only allow DawnDeposit");
        _;
    }

}