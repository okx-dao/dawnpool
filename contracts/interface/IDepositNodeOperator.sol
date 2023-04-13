// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

interface IDepositNodeOperator {
    function getOperator() external view returns (address);
}
