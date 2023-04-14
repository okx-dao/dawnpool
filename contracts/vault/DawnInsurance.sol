// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDawnInsurance.sol";
import "../base/DawnBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDawnDeposit {
    function receiveFromInsurance(uint256 pEthAmount) external;
}

contract DawnInsurance is IDawnInsurance, DawnBase {
    constructor(IDawnStorageInterface dawnStorageAddress) DawnBase(dawnStorageAddress) {}

    function transferToStakingPool(uint256 amountPEth) external {
        //todo: ACL
        require(_getContractAddress("DawnDeposit") != address(0), "pETH token not exists");
        address pETH = _getContractAddress("DawnDeposit");
        amountPEth = IERC20(pETH).balanceOf(address(this)) > amountPEth
            ? amountPEth
            : IERC20(pETH).balanceOf(address(this));
        IDawnDeposit(pETH).receiveFromInsurance(amountPEth);
    }
}
