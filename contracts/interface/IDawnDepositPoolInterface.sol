// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

interface IDawnDepositPoolInterface {
    /// 获取ETH余额
    function getBalance() external view returns (uint256);
    /// 质押ETH
    function deposit() external payable;
    /// 提取ETH
    function withdraw(uint256 _amount) external;
}