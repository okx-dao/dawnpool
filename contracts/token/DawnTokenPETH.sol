// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interface/IDawnTokenPETH.sol";
import "../base/DawnBase.sol";

contract DawnTokenPETH is DawnBase, IDawnTokenPETH, ERC20 {

    using SafeERC20 for IERC20;

    constructor(IDawnStorageInterface _dawnStorageAddress) DawnBase(_dawnStorageAddress) ERC20("Dawn Pool ETH", "pETH") {

    }

    function mint(uint256 _ethAmount, address _to) override external onlyLatestContract("dawnDepositPool", msg.sender) {

    }

    function burn(uint256 _pethAmount) override external view {
        require(_pethAmount > 0, "Invalid token burn amount");
        require(balanceOf(msg.sender) >= _pethAmount, "Insufficient pETH balance");
    }
}