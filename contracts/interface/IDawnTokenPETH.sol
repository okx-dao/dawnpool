// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDawnTokenPETH is IERC20 {
    function mint(uint256 ethAmount, address to) external;
    function burn(uint256 pethAmount) external;
}