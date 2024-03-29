// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "../interface/IBurner.sol";
import "../base/DawnBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interface/IDawnDeposit.sol";

contract Burner is IBurner, DawnBase {
    bytes32 internal constant _TOTAL_BURNED_PETH = keccak256("burner.totalBurnedPEth");
    bytes32 internal constant _PETH_BURN_REQUESTED = keccak256("burner.totalPEthBurnRequested");

    bytes32 internal constant _TOTAL_DECREASED_ETH = keccak256("burner.totalDecreasedEth");
    bytes32 internal constant _ETH_DECREASE_REQUESTED = keccak256("burner.totalEthDecreaseRequested");

    // ***************** contract name *****************
    string internal constant _DAWN_DEPOSIT_CONTRACT_NAME = "DawnDeposit";
    string internal constant _DAWN_WITHDRAW_CONTRACT_NAME = "DawnWithdraw";

    event LogRequestBurnPETH(address from, uint256 amount);
    event LogRequestBurnPEthAndDecreaseEth(address from, uint256 burnedPEthAmount, uint256 decreaseEthAmount);
    event LogRequestBurnMyPEth(uint256 amount);
    event LogSubmitBurnRequest(uint256 burnedPEthAmount, uint256 totalBurnedPEth, uint256 currPEthBurnRequest);

    error ZeroAddress();
    error PEthNotEnough();
    error ZeroBurnAmount();

    // constructor
    constructor(IDawnStorageInterface dawnStorageAddress) DawnBase(dawnStorageAddress) {}

    function requestBurnPEth(address from, uint256 amount) external onlyDawnDepositOrWithdraw {
        _addUint(_PETH_BURN_REQUESTED, amount);
        emit LogRequestBurnPETH(from, amount);
    }

    function requestBurnPEthAndDecreaseEth(
        address from,
        uint256 burnedPEthAmount,
        uint256 decreaseEthAmount
    ) external onlyDawnDepositOrWithdraw {
        _addUint(_PETH_BURN_REQUESTED, burnedPEthAmount);
        _addUint(_ETH_DECREASE_REQUESTED, decreaseEthAmount);
        emit LogRequestBurnPEthAndDecreaseEth(from, burnedPEthAmount, decreaseEthAmount);
    }

    //    function requestBurnMyPEth(uint256 amount) external {
    //        if (amount == 0) revert ZeroBurnAmount();
    //
    //        IERC20 PEth = IERC20(_getContractAddress(_DAWN_DEPOSIT_CONTRACT_NAME));
    //        if (PEth.balanceOf(msg.sender) < amount) revert PEthNotEnough();
    //        PEth.transfer(address(this), amount);
    //        _addUint(_PETH_BURN_REQUESTED, amount);
    //
    //        emit LogRequestBurnMyPEth(amount);
    //    }

    function commitPEthToBurn(uint256 burnedPEthAmount) external {
        require(msg.sender == _getContractAddress(_DAWN_DEPOSIT_CONTRACT_NAME), "caller is not DawnDeposit contract");
        require(burnedPEthAmount <= _getPEthBurnRequest(), "burnedPEthAmount more than totalPEthBurnRequested");
        // update
        _subUint(_PETH_BURN_REQUESTED, burnedPEthAmount);
        _addUint(_TOTAL_BURNED_PETH, burnedPEthAmount);

        uint256 decreasedEthAmount = _getUint(_ETH_DECREASE_REQUESTED);
        if (decreasedEthAmount > 0) {
            _addUint(_TOTAL_DECREASED_ETH, decreasedEthAmount);
            _setUint(_ETH_DECREASE_REQUESTED, 0);
            IDawnDeposit(_getContractAddress(_DAWN_DEPOSIT_CONTRACT_NAME)).increaseUnreachableEtherCount(
                decreasedEthAmount
            );
        }
        // emit SubmitBurnRequest
        emit LogSubmitBurnRequest(burnedPEthAmount, _getTotalBurnedPEth(), _getPEthBurnRequest());
    }

    function getTotalBurnedPEth() public view returns (uint256) {
        return _getTotalBurnedPEth();
    }

    function getPEthBurnRequest() public view returns (uint256) {
        return _getPEthBurnRequest();
    }

    function _getTotalBurnedPEth() internal view returns (uint256) {
        return _getUint(_TOTAL_BURNED_PETH);
    }

    function _getPEthBurnRequest() internal view returns (uint256) {
        return _getUint(_PETH_BURN_REQUESTED);
    }

    modifier onlyDawnDepositOrWithdraw() {
        require(
            msg.sender == _getContractAddress(_DAWN_DEPOSIT_CONTRACT_NAME) ||
                msg.sender == _getContractAddress(_DAWN_WITHDRAW_CONTRACT_NAME),
            "Only call by dawnDeposit or dawnWithdraw"
        );
        _;
    }
}
