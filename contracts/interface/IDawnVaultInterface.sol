// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// 金库合约接口
interface IDawnVaultInterface {
    /// 查询某个合约地址上的ETH余额
    function balanceOf(string memory _networkContractName) external view returns (uint256);
    /// 提取ETH
    function withdrawEther(uint256 _amount) external;
    /// 提取ERC20代币
    function withdrawToken(address _withdrawalAddress, IERC20 _tokenAddress, uint256 _amount) external;
    /// 查询ERC20代币余额
    function balanceOfToken(string memory _networkContractName, IERC20 _tokenAddress) external view returns (uint256);
    /// 转移ERC20代币
    function transferToken(string memory _networkContractName, IERC20 _tokenAddress, uint256 _amount) external;
}
