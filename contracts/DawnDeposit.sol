// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "./interface/IDawnDeposit.sol";
import "./DawnTokenPETH.sol";
import "./lib/PositionStorage.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./RewardsValut.sol";

interface IRewardsVault {
    function withdrawRewards(uint256 availableRewards) external;
}

contract DawnDeposit is IDawnDeposit, DawnTokenPETH {

    using SafeMath for uint256;
    using PositionStorage for byte32;

    uint256 public constant DEPOSIT_VALUE_PER_VALIDATOR = 32 ether;
    uint256 internal constant FEE_BASIC = 10000;

    bytes32 internal constant BUFFERED_ETHER_POSITION = keccak256("dawn.pool.buffered.ether");
    bytes32 internal constant DEPOSITED_VALIDATORS_POSITION = keccak256("dawn.pool.deposited.validators");
    bytes32 internal constant BEACON_VALIDATORS_POSITION = keccak256("dawn.pool.beacon.validators");
    bytes32 internal constant BEACON_BALANCE_POSITION = keccak256("dawn.pool.beacon.balance");

    bytes32 internal constant FEE_POSITION = keccak256("dawn.pool.fee");
    bytes32 internal constant INSURANCE_FEE_POSITION = keccak256("dawn.pool.insurance.fee");
    bytes32 internal constant TREASURY_FEE_POSITION = keccak256("dawn.pool.treasury.fee");
    bytes32 internal constant NODE_OPERATOR_FEE_POSITION = keccak256("dawn.pool.nodeOperator.fee");

    bytes32 internal constant REWARDS_VAULT_POSITION = keccak256("dawn.pool.rewardsVault");
    bytes32 internal constant TREASURY_POSITION = keccak256("dawn.pool.treasury");
    bytes32 internal constant INSURANCE_POSITION = keccak256("dawn.pool.insurance");
    bytes32 internal constant NODE_OPERATOR_REGISTER_POSITION = keccak256("dawn.pool.nodeOperatorRegister");



    // user stake ETH to DawnPool returns pETH
    function stake() external payable returns (uint256) {
        require(msg.value != 0, "STAKE_ZERO_ETHER");

        uint256 pEthAmount = getPEthByEther(msg.value);
        if (pEthAmount == 0) {
            pEthAmount = msg.value;
        }
        _mint(msg.sender, pEthAmount);

        BUFFERED_ETHER_POSITION.setStorageUint256(
            BUFFERED_ETHER_POSITION.getStorageUint256().add(msg.value)
        );
        emit Stake(msg.sender, msg.value);

        return pEthAmount;
    }
    // user unstake pETH from DawnPool returns ETH
    function unstake(uint pEthAmount) external returns (uint256) {

    }

    // receive ETH rewards from RewardsVault
    function receiveRewards() external payable {

    }
    // distribute pETH rewards to NodeOperators、DawnInsurance、DawnTreasury
    function distributeRewards(uint256 rewardsPEth) internal {

    }
    // transfer pETH as rewards to DawnInsurance
    function transferToInsurance(uint256 rewardsPEth) internal {

    }
    // transfer pETH as rewards to DawnTreasury
    function transferToTreasury(uint256 rewardsPEth) internal {

    }
    // distribute pETH as rewards to NodeOperators
    function distributeNodeOperatorRewards(uint256 rewardsPEth) internal {

    }

    // handle oracle report
    function handleOracleReport(uint256 beaconValidators, uint256 beaconBalance, uint256 availableRewards) external {
        require(availableRewards <= getRewardsVault().balance, "RewardsVault insufficient balance");
        require(
            beaconBalance.add(availableRewards)
            >=
            BEACON_BALANCE_POSITION.getStorageUint256()
            .add(
                beaconValidators
                .sub(BEACON_VALIDATORS_POSITION.getStorageUint256())
                .mul(DEPOSIT_VALUE_PER_VALIDATOR)
            ), "unprofitable");

        uint256 rewards = beaconBalance
        .add(availableRewards)
        .sub(
            BEACON_BALANCE_POSITION.getStorageUint256()
            .add(
                beaconValidators
                .sub(BEACON_VALIDATORS_POSITION.getStorageUint256())
                .mul(DEPOSIT_VALUE_PER_VALIDATOR)
            )
        );

        uint256 preTotalEther = getTotalPooledEther();
        uint256 preTotalPEth = totalSupply();

        // store beacon balance and validators
        BEACON_VALIDATORS_POSITION.setStorageUint256(beaconValidators);
        BEACON_BALANCE_POSITION.setStorageUint256(beaconBalance);

        // claim availableRewards from RewardsVault
        IRewardsVault(getRewardsVault()).withdrawRewards(availableRewards);


        // calculate rewardsPEth
        // rewardsPEth / (rewards * fee/basic) = preTotalPEth / (preTotalEther + rewards * (basic - fee)/basic)
        // rewardsPEth / (rewards * fee) = preTotalPEth / (preTotalEther * basic + rewards * (basic - fee))
        // rewardsPEth = preTotalPEth * rewards * fee / (preTotalEther * basic + rewards * (basic - fee))
        uint256 rewardsPEth = preTotalPEth
        .mul(rewards)
        .mul(FEE_POSITION.getStorageUint256())
        .div(
            preTotalEther
            .mul(FEE_BASIC)
            .add(
                rewards
                .mul(
                    FEE_BASIC
                    .sub(FEE_POSITION.getStorageUint256())
                )
            )
        );
        // distributeRewards
        distributeRewards(rewardsPEth);
    }

    // receive pETH from Treasury, and burn pETH
    function receiveFromTreasury(uint256 pEthAmount) external {

    }


    // deposit 32 ETH to activate validator
    function activateValidator() external {

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
        return BUFFERED_ETHER_POSITION.getStorageUint256()
        .add(BEACON_BALANCE_POSITION.getStorageUint256())
        .add(DEPOSITED_VALIDATORS_POSITION.getStorageUint256()
            .sub(BEACON_VALIDATORS_POSITION.getStorageUint256())
            .mul(DEPOSIT_VALUE_PER_VALIDATOR.getStorageUint256())
        );
    }

    function getRewardsVault() public view returns (address) {
        return REWARDS_VAULT_POSITION.getStorageAddress();
    }

    function getTreasury() public view returns (address) {
        return TREASURY_POSITION.getStorageAddress();
    }

    function getInsurance() public view returns (address) {
        return INSURANCE_POSITION.getStorageAddress();
    }

    receive() external payable {
        stake();
    }

    fallback() external payable {
        stake();
    }

}