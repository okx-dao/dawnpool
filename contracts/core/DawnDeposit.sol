// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDawnDeposit.sol";
import "../token/DawnTokenPETH.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../base/DawnBase.sol";

interface IRewardsVault {
    function withdrawRewards(uint256 availableRewards) external;
}

contract DawnDeposit is IDawnDeposit, DawnTokenPETH, DawnBase {
    using SafeMath for uint256;

    uint256 public constant DEPOSIT_VALUE_PER_VALIDATOR = 32 ether;
    uint256 internal constant _FEE_BASIC = 10000;

    bytes32 internal constant _BUFFERED_ETHER_KEY = keccak256("dawnDeposit.bufferedEther");
    bytes32 internal constant _DEPOSITED_VALIDATORS_KEY = keccak256("dawnDeposit.depositedValidators");
    bytes32 internal constant _BEACON_VALIDATORS_KEY = keccak256("dawnDeposit.beaconValidators");
    bytes32 internal constant _BEACON_BALANCE_KEY = keccak256("dawnDeposit.beaconBalance");

    bytes32 internal constant _FEE_KEY = keccak256("dawnDeposit.fee");
    bytes32 internal constant _INSURANCE_FEE_KEY = keccak256("dawnDeposit.insuranceFee");
    bytes32 internal constant _TREASURY_FEE_KEY = keccak256("dawnDeposit.treasuryFee");
    bytes32 internal constant _NODE_OPERATOR_FEE_KEY = keccak256("dawnDeposit.nodeOperatorFee");

    string internal constant _REWARDS_VAULT_CONTRACT_NAME = "RewardsVault";
    string internal constant _TREASURY_CONTRACT_NAME = "DawnTreasury";
    string internal constant _INSURANCE_CONTRACT_NAME = "DawnInsurance";
    string internal constant _NODE_OPERATOR_REGISTER_CONTRACT_NAME = "DepositNodeManager";
    string internal constant _ORACLE_CONTRACT_NAME = "DawnPoolOracle";

    // constructor
    constructor(IDawnStorageInterface dawnStorageAddress) DawnTokenPETH() DawnBase(dawnStorageAddress) {}

    receive() external payable {
        _stake();
    }

//    fallback() external payable {
//        _stake();
//    }

    // user stake ETH to DawnPool returns pETH
    function stake() external payable returns (uint256) {
        return _stake();
    }

    // user unstake pETH from DawnPool returns ETH
    function unstake(uint pEthAmount) external returns (uint256) {
        return pEthAmount;
    }

    // receive pETH from Insurance, and burn pETH
    function receiveFromInsurance(uint256 pEthAmount) external {
        require(msg.sender == _getContractAddress(_INSURANCE_CONTRACT_NAME), "receive not from insurance");

        // burn insurance's pEth
        _burn(_getContractAddress(_INSURANCE_CONTRACT_NAME), pEthAmount);

        emit LogReceiveInsurance(pEthAmount);
    }

    // deposit 31 ETH to activate validator
    function activateValidator(
        address operator,
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external {}

    // deposit 1 ETH for NodeOperatorRegister
    function preActivateValidator(
        address operator,
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external {}

    // receive ETH rewards from RewardsVault
    function receiveRewards() external payable {
        emit LogReceiveRewards(msg.value);
    }

    // handle oracle report
    function handleOracleReport(uint256 beaconValidators, uint256 beaconBalance, uint256 availableRewards) external {
        require(msg.sender == _getContractAddress(_ORACLE_CONTRACT_NAME), "only call by DawnPoolOracle");
        require(
            availableRewards <= _getContractAddress(_REWARDS_VAULT_CONTRACT_NAME).balance,
            "RewardsVault insufficient balance"
        );
        require(
            beaconBalance.add(availableRewards) >=
                _getUint(_BEACON_BALANCE_KEY).add(
                    beaconValidators.sub(_getUint(_BEACON_VALIDATORS_KEY)).mul(DEPOSIT_VALUE_PER_VALIDATOR)
                ),
            "unprofitable"
        );

        uint256 rewards = beaconBalance.add(availableRewards).sub(
            _getUint(_BEACON_BALANCE_KEY).add(
                beaconValidators.sub(_getUint(_BEACON_VALIDATORS_KEY)).mul(DEPOSIT_VALUE_PER_VALIDATOR)
            )
        );

        uint256 preTotalEther = getTotalPooledEther();
        uint256 preTotalPEth = totalSupply();

        // store beacon balance and validators
        _setUint(_BEACON_VALIDATORS_KEY, beaconValidators);
        _setUint(_BEACON_BALANCE_KEY, beaconBalance);

        // claim availableRewards from RewardsVault
        IRewardsVault(_getContractAddress(_REWARDS_VAULT_CONTRACT_NAME)).withdrawRewards(availableRewards);

        // calculate rewardsPEth
        // rewardsPEth / (rewards * fee/basic) = preTotalPEth / (preTotalEther + rewards * (basic - fee)/basic)
        // rewardsPEth / (rewards * fee) = preTotalPEth / (preTotalEther * basic + rewards * (basic - fee))
        // rewardsPEth = preTotalPEth * rewards * fee / (preTotalEther * basic + rewards * (basic - fee))
        uint256 rewardsPEth = preTotalPEth.mul(rewards).mul(_getUint(_FEE_KEY)).div(
            preTotalEther.mul(_FEE_BASIC).add(rewards.mul(_FEE_BASIC.sub(_getUint(_FEE_KEY))))
        );
        // distributeRewards
        _distributeRewards(rewardsPEth);
    }

    // calculate the amount of pETH backing an amount of ETH
    function getEtherByPEth(uint256 pEthAmount) public view returns (uint256) {
        uint256 totalPEth = totalSupply();
        if (totalPEth == 0) return 0;

        uint256 totalEther = getTotalPooledEther();
        return totalEther.mul(pEthAmount).div(totalPEth);
    }

    // calculate the amount of ETH backing an amount of pETH
    function getPEthByEther(uint256 ethAmount) public view returns (uint256) {
        uint256 totalEther = getTotalPooledEther();
        if (totalEther == 0) return 0;

        uint256 totalPEth = totalSupply();
        return totalPEth.mul(ethAmount).div(totalEther);
    }

    // get DawnPool protocol total value locked
    function getTotalPooledEther() public view returns (uint256) {
        return
            _getUint(_BUFFERED_ETHER_KEY).add(_getUint(_BEACON_BALANCE_KEY)).add(
                _getUint(_DEPOSITED_VALIDATORS_KEY).sub(_getUint(_BEACON_VALIDATORS_KEY)).mul(
                    DEPOSIT_VALUE_PER_VALIDATOR
                )
            );
    }

    // distribute pETH rewards to NodeOperators、DawnInsurance、DawnTreasury
    function _distributeRewards(uint256 rewardsPEth) internal {
        uint256 insuranceFee = _getUint(_INSURANCE_FEE_KEY);
        uint256 treasuryFee = _getUint(_TREASURY_FEE_KEY);
        uint256 nodeOperatorFee = _getUint(_NODE_OPERATOR_FEE_KEY);
        _transferToInsurance(rewardsPEth.mul(insuranceFee).div(_FEE_BASIC));
        _transferToTreasury(rewardsPEth.mul(treasuryFee).div(_FEE_BASIC));
        _distributeNodeOperatorRewards(rewardsPEth.mul(nodeOperatorFee).div(_FEE_BASIC));
    }

    // transfer pETH as rewards to DawnInsurance
    function _transferToInsurance(uint256 rewardsPEth) internal {
        _mint(_getContractAddress(_INSURANCE_CONTRACT_NAME), rewardsPEth);
    }

    // transfer pETH as rewards to DawnTreasury
    function _transferToTreasury(uint256 rewardsPEth) internal {
        _mint(_getContractAddress(_TREASURY_CONTRACT_NAME), rewardsPEth);
    }

    // distribute pETH as rewards to NodeOperators
    function _distributeNodeOperatorRewards(uint256 rewardsPEth) internal {
        // todo
    }

    function _stake() internal returns (uint256) {
        require(msg.value != 0, "STAKE_ZERO_ETHER");

        uint256 pEthAmount = getPEthByEther(msg.value);
        if (pEthAmount == 0) {
            pEthAmount = msg.value;
        }
        _mint(msg.sender, pEthAmount);
        // update buffered ether
        _addUint(_BUFFERED_ETHER_KEY, msg.value);

        emit LogStake(msg.sender, msg.value);
        return pEthAmount;
    }
}
