// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

interface IDawnDeposit {
    event LogStake(address indexed staker, uint256 ethAmount);
    event LogReceiveRewards(uint256 ethAmount);
    event LogReceiveInsurance(uint256 pEthAmount);
    event LogPreActivateValidator(address operator, bytes pubkey, uint256 amount);
    event LogActivateValidator(address operator, bytes pubkey, uint256 amount);

    // user stake ETH to DawnPool returns pETH
    function stake() external payable returns (uint256);

    // user unstake pETH from DawnPool returns ETH
    function unstake(uint pEthAmount) external returns (uint256);

    // receive ETH rewards from RewardsVault
    function receiveRewards() external payable;

    // handle oracle report
    function handleOracleReport(
        uint256 epochId,
        uint256 beaconValidators,
        uint256 beaconBalance,
        uint256 availableRewards,
        uint256 exitedValidators
    ) external;

    // receive pETH from Insurance, and burn
    function receiveFromInsurance(uint256 pEthAmount) external;

    function getBeaconStat() external view returns (uint256 depositedValidators, uint256 beaconValidators, uint256 beaconBalance);
    function getBufferedEther() external view returns (uint256);

    // calculate the amount of pETH backing an amount of ETH
    function getEtherByPEth(uint256 pEthAmount) external view returns (uint256);

    // calculate the amount of ETH backing an amount of pETH
    function getPEthByEther(uint256 ethAmount) external view returns (uint256);

    // get DawnPool protocol total value locked
    function getTotalPooledEther() external view returns (uint256);

    // deposit 31 ETH to activate validator
    function activateValidator(
        address operator,
        bytes calldata pubkey,
        bytes calldata signature
    ) external;

    // deposit 1 ETH for NodeOperatorRegister
    function preActivateValidator(
        address operator,
        bytes calldata pubkey,
        bytes calldata signature
    ) external;
}
