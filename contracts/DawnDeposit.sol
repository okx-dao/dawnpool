// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "./interface/IDawnDeposit.sol";
import "./token/DawnTokenPETH.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./base/DawnBase.sol";

interface IRewardsVault {
    function withdrawRewards(uint256 availableRewards) external;
}

contract DawnDeposit is IDawnDeposit, DawnTokenPETH, DawnBase {

    using SafeMath for uint256;

    uint256 public constant DEPOSIT_VALUE_PER_VALIDATOR = 32 ether;
    uint256 internal constant FEE_BASIC = 10000;

    bytes32 internal constant BUFFERED_ETHER_KEY = keccak256("dawnDeposit.bufferedEther");
    bytes32 internal constant DEPOSITED_VALIDATORS_KEY  = keccak256("dawnDeposit.depositedValidators");
    bytes32 internal constant BEACON_VALIDATORS_KEY = keccak256("dawnDeposit.beaconValidators");
    bytes32 internal constant BEACON_BALANCE_KEY = keccak256("dawnDeposit.beaconBalance");

    bytes32 internal constant FEE_KEY = keccak256("dawnDeposit.fee");
    bytes32 internal constant INSURANCE_FEE_KEY = keccak256("dawnDeposit.insuranceFee");
    bytes32 internal constant TREASURY_FEE_KEY = keccak256("dawnDeposit.treasuryFee");
    bytes32 internal constant NODE_OPERATOR_FEE_KEY = keccak256("dawnDeposit.nodeOperatorFee");

    string internal constant REWARDS_VAULT_CONTRACT_NAME = "RewardsVault";
    string internal constant TREASURY_CONTRACT_NAME = "DawnTreasury";
    string internal constant INSURANCE_CONTRACT_NAME = "DawnInsurance";
    string internal constant NODE_OPERATOR_REGISTER_CONTRACT_NAME = "NodeOperatorRegister";

    // constructor
    constructor(IDawnStorageInterface _dawnStorageAddress) DawnTokenPETH() DawnBase(_dawnStorageAddress) {

    }

    // user stake ETH to DawnPool returns pETH
    function stake() external payable returns (uint256) {
        require(msg.value != 0, "STAKE_ZERO_ETHER");

        uint256 pEthAmount = getPEthByEther(msg.value);
        if (pEthAmount == 0) {
            pEthAmount = msg.value;
        }
        _mint(msg.sender, pEthAmount);

        addUint(BUFFERED_ETHER_KEY, msg.value);

        emit LogStake(msg.sender, msg.value);

        return pEthAmount;
    }

    // user unstake pETH from DawnPool returns ETH
    function unstake(uint pEthAmount) external returns (uint256) {
        return 0;
    }

    // receive pETH from Insurance, and burn pETH
    function receiveFromInsurance(uint256 pEthAmount) external {

    }

    // deposit 32 ETH to activate validator
    function activateValidator() external {

    }

    // receive ETH rewards from RewardsVault
    function receiveRewards() external payable {
        emit LogReceiveRewards(msg.value);
    }

    // handle oracle report
    function handleOracleReport(uint256 beaconValidators, uint256 beaconBalance, uint256 availableRewards) external {
        require(availableRewards <= getContractAddress(REWARDS_VAULT_CONTRACT_NAME).balance, "RewardsVault insufficient balance");
        require(
            beaconBalance.add(availableRewards)
            >=
            getUint(BEACON_BALANCE_KEY)
            .add(
                beaconValidators
                .sub(getUint(BEACON_VALIDATORS_KEY))
                .mul(DEPOSIT_VALUE_PER_VALIDATOR)
            ), "unprofitable");

        uint256 rewards = beaconBalance
        .add(availableRewards)
        .sub(
            getUint(BEACON_BALANCE_KEY)
            .add(
                beaconValidators
                .sub(getUint(BEACON_VALIDATORS_KEY))
                .mul(DEPOSIT_VALUE_PER_VALIDATOR)
            )
        );

        uint256 preTotalEther = getTotalPooledEther();
        uint256 preTotalPEth = totalSupply();

        // store beacon balance and validators
        setUint(BEACON_VALIDATORS_KEY, beaconValidators);
        setUint(BEACON_BALANCE_KEY, beaconBalance);

        // claim availableRewards from RewardsVault
        IRewardsVault(getContractAddress(REWARDS_VAULT_CONTRACT_NAME)).withdrawRewards(availableRewards);

        // calculate rewardsPEth
        // rewardsPEth / (rewards * fee/basic) = preTotalPEth / (preTotalEther + rewards * (basic - fee)/basic)
        // rewardsPEth / (rewards * fee) = preTotalPEth / (preTotalEther * basic + rewards * (basic - fee))
        // rewardsPEth = preTotalPEth * rewards * fee / (preTotalEther * basic + rewards * (basic - fee))
        uint256 rewardsPEth = preTotalPEth
        .mul(rewards)
        .mul(getUint(FEE_KEY))
        .div(
            preTotalEther
            .mul(FEE_BASIC)
            .add(
                rewards
                .mul(
                    FEE_BASIC
                    .sub(getUint(FEE_KEY))
                )
            )
        );
        // distributeRewards
        distributeRewards(rewardsPEth);
    }

    // distribute pETH rewards to NodeOperators、DawnInsurance、DawnTreasury
    function distributeRewards(uint256 rewardsPEth) internal {
        uint256 insuranceFee = getUint(INSURANCE_FEE_KEY);
        uint256 treasuryFee = getUint(TREASURY_FEE_KEY);
        uint256 nodeOperatorFee = getUint(NODE_OPERATOR_FEE_KEY);
        transferToInsurance(rewardsPEth.mul(insuranceFee).div(FEE_BASIC));
        transferToTreasury(rewardsPEth.mul(treasuryFee).div(FEE_BASIC));
        distributeNodeOperatorRewards(rewardsPEth.mul(nodeOperatorFee).div(FEE_BASIC));
    }
    // transfer pETH as rewards to DawnInsurance
    function transferToInsurance(uint256 rewardsPEth) internal {
        transfer(getContractAddress(INSURANCE_CONTRACT_NAME), rewardsPEth);
    }
    // transfer pETH as rewards to DawnTreasury
    function transferToTreasury(uint256 rewardsPEth) internal {
        transfer(getContractAddress(TREASURY_CONTRACT_NAME), rewardsPEth);
    }
    // distribute pETH as rewards to NodeOperators
    function distributeNodeOperatorRewards(uint256 rewardsPEth) internal {
        // todo
    }

    // calculate the amount of pETH backing an amount of ETH
    function getEtherByPEth(uint256 pEthAmount) internal view returns (uint256) {
        uint256 totalPEth = totalSupply();
        if (totalPEth == 0) return 0;

        uint256 totalEther = getTotalPooledEther();
        return totalEther.mul(pEthAmount).div(totalPEth);
    }

    // calculate the amount of ETH backing an amount of pETH
    function getPEthByEther(uint256 ethAmount) internal view returns (uint256) {
        uint256 totalEther = getTotalPooledEther();
        if (totalEther == 0) return 0;

        uint256 totalPEth = totalSupply();
        return totalPEth.mul(ethAmount).div(totalEther);
    }

    // get DawnPool protocol total value locked
    function getTotalPooledEther() internal view returns (uint256) {
        return getUint(BUFFERED_ETHER_KEY)
        .add(getUint(BEACON_BALANCE_KEY))
        .add(
            getUint(DEPOSITED_VALIDATORS_KEY)
            .sub(getUint(BEACON_VALIDATORS_KEY))
            .mul(DEPOSIT_VALUE_PER_VALIDATOR)
        );
    }


    receive() external payable {
        this.stake();
    }

    fallback() external payable {
        this.stake();
    }

    function mintSharesForNodeOperator(address to, uint256 ethAmount) external {


    }
}
