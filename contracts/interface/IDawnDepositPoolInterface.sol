// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

interface IDawnDepositPoolInterface {
    function getBalance() external view returns (uint256);
    function deposit() external payable;
    function withdraw(uint256 _amount) external;
}