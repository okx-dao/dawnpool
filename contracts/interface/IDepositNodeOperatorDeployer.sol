// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

interface IDepositNodeOperatorDeployer {
    function deployDepositNodeOperator(address operator) external returns (address);
}
