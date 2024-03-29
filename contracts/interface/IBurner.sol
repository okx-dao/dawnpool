// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

interface IBurner {
    function requestBurnPEth(address from, uint256 amount) external;

    function requestBurnPEthAndDecreaseEth(address from, uint256 burnedPEthAmount, uint256 decreaseEthAmount) external;

    //    function requestBurnMyPEth(uint256 amount) external;
    function commitPEthToBurn(uint256 burnedPEthAmount) external;

    function getTotalBurnedPEth() external view returns (uint256);

    function getPEthBurnRequest() external view returns (uint256);
}
