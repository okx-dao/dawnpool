// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev 金库合约接口:
 *
 * （以下是合约接口描述内容、主要的接口功能描述）
 *
 */
interface IDawnVault {
    /**
     * @dev 查询某个合约地址上的ETH余额.
     * @param networkContractName - DawnPool合约名称.
     * @return 某合约上的ETH数量.
     */
    function balanceOf(string memory networkContractName) external view returns (uint256);

    /**
     * @dev 提取ETH.
     * @param amount - 提取ETH的数量.
     */
    function withdrawEther(uint256 amount) external;

    /**
     * @dev 提取ERC20代币.
     * @param withdrawalAddress - 提取代币的地址.
     * @param tokenAddress - 提取代币的ERC20合约地址.
     * @param amount - 提取代币的数量.
     */
    function withdrawToken(address withdrawalAddress, IERC20 tokenAddress, uint256 amount) external;

    /**
     * @dev 查询ERC20代币余额.
     * @param networkContractName - 查询代币的合约名称.
     * @param tokenAddress - 代币的ERC20合约地址.
     * @return 某合约上的token数量.
     */
    function balanceOfToken(string memory networkContractName, IERC20 tokenAddress) external view returns (uint256);

    /**
     * @dev 转移ERC20代币.
     * @param networkContractName - 代币的合约名称.
     * @param tokenAddress - 代币的ERC20合约地址.
     * @param amount - 代币的数量.
     */
    function transferToken(string memory networkContractName, IERC20 tokenAddress, uint256 amount) external;
}
