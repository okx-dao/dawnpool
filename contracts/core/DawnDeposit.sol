// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "../interface/IDawnDeposit.sol";
import "../token/DawnTokenPETH.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../base/DawnBase.sol";
import "../interface/IDepositNodeManager.sol";
import "../interface/IRewardsVault.sol";
import "../deposit_contract/deposit_contract.sol";
import "../interface/IBurner.sol";
import "../interface/IDawnWithdraw.sol";

contract DawnDeposit is IDawnDeposit, DawnTokenPETH, DawnBase {
    using SafeMath for uint256;

    uint256 internal constant _DEPOSIT_VALUE_PER_VALIDATOR = 32 ether;
    uint256 internal constant _PRE_DEPOSIT_VALUE = 1 ether;
    uint256 internal constant _POST_DEPOSIT_VALUE = 31 ether;
    uint256 internal constant _FEE_BASIC = 10000;
    bytes1 internal constant _WITHDRAWAL_PREFIX = 0x01;

    bytes32 internal constant _BUFFERED_ETHER_KEY = keccak256("dawnDeposit.bufferedEther");
    bytes32 internal constant _PRE_DEPOSIT_VALIDATORS_KEY = keccak256("dawnDeposit.preDepositValidators");
    bytes32 internal constant _DEPOSITED_VALIDATORS_KEY = keccak256("dawnDeposit.depositedValidators");
    bytes32 internal constant _BEACON_ACTIVE_VALIDATORS_KEY = keccak256("dawnDeposit.beaconActiveValidators");
    bytes32 internal constant _BEACON_ACTIVE_VALIDATOR_BALANCE_KEY =
        keccak256("dawnDeposit.beaconActiveValidatorBalance");
    bytes32 internal constant _UNREACHABLE_ETHER_COUNT_KEY = keccak256("dawnDeposit.unreachableEtherCount");

    bytes32 internal constant _FEE_KEY = keccak256("dawnDeposit.fee");
    bytes32 internal constant _INSURANCE_FEE_KEY = keccak256("dawnDeposit.insuranceFee");
    bytes32 internal constant _TREASURY_FEE_KEY = keccak256("dawnDeposit.treasuryFee");
    bytes32 internal constant _NODE_OPERATOR_FEE_KEY = keccak256("dawnDeposit.nodeOperatorFee");

    // ***************** contract name *****************
    string internal constant _REWARDS_VAULT_CONTRACT_NAME = "RewardsVault";
    string internal constant _TREASURY_CONTRACT_NAME = "DawnTreasury";
    string internal constant _INSURANCE_CONTRACT_NAME = "DawnInsurance";
    string internal constant _NODE_OPERATOR_REGISTER_CONTRACT_NAME = "DepositNodeManager";
    string internal constant _ORACLE_CONTRACT_NAME = "DawnPoolOracle";
    string internal constant _DEPOSIT_NODE_MANAGER = "DepositNodeManager";
    string internal constant _DEPOSIT_CONTRACT_NAME = "DepositContract";
    string internal constant _BURNER_CONTRACT_NAME = "Burner";
    string internal constant _DAWN_WITHDRAW_CONTRACT_NAME = "DawnWithdraw";

    error ZeroAddress();
    error PEthNotEnough();
    error ZeroBurnAmount();
    error ErrorBurnedPEthAmount(uint256 burnedPEthAmount, uint256 burnerBalance);
    error InvalidValidators(uint256 beaconValidators, uint256 exitedValidators, uint256 depositedValidators);
    error Unprofitable();
    error RewardsVaultBalanceNotEnough();
    error ReceiveNotFromInsurance(address from);
    error BufferedEtherNotEnough();
    error InvalidLockEth(uint256 ethAmountToLock);
    error StakeZeroEther();
    error CallerAuthFailed(address from);
    error NodeOperatorInactive(address nodeAddress);

    // constructor
    constructor(IDawnStorageInterface dawnStorageAddress) DawnTokenPETH() DawnBase(dawnStorageAddress) {}

    // ***************** external function *****************
    receive() external payable {
        _stake();
    }

    // user stake ETH to DawnPool returns pETH
    function stake() external payable returns (uint256) {
        return _stake();
    }

    // receive pETH from Insurance, and burn pETH
    function receiveFromInsurance(uint256 pEthAmount) external {
        if (msg.sender != _getContractAddress(_INSURANCE_CONTRACT_NAME)) {
            revert ReceiveNotFromInsurance(msg.sender);
        }

        // burn insurance's pEth
        //_burn(_getContractAddress(_INSURANCE_CONTRACT_NAME), pEthAmount);
        _transfer(msg.sender, _getContractAddress(_BURNER_CONTRACT_NAME), pEthAmount);
        IBurner(_getContractAddress(_BURNER_CONTRACT_NAME)).requestBurnPEth(msg.sender, pEthAmount);

        emit LogReceiveInsurance(pEthAmount);
    }

    // deposit 31 ETH to activate validator
    function activateValidator(
        address operator,
        bytes calldata pubkey,
        bytes calldata signature
    ) external onlyActiveNodeOperator(operator) {
        if (address(this).balance < _POST_DEPOSIT_VALUE) {
            revert BufferedEtherNotEnough();
        }
        bytes32 withdrawalCredentials = _getWithdrawalCredentials();
        _doDeposit(pubkey, withdrawalCredentials, signature, _POST_DEPOSIT_VALUE);

        // update deposited validators
        _addUint(_DEPOSITED_VALIDATORS_KEY, 1);
        // update pre deposit validators
        _subUint(_PRE_DEPOSIT_VALIDATORS_KEY, 1);
        // update buffered ether
        _subUint(_BUFFERED_ETHER_KEY, _POST_DEPOSIT_VALUE);

        // emit event
        emit LogActivateValidator(operator, pubkey, _POST_DEPOSIT_VALUE);
    }

    // deposit 1 ETH for NodeOperatorRegister
    function preActivateValidator(
        address operator,
        bytes calldata pubkey,
        bytes calldata signature
    ) external onlyActiveNodeOperator(operator) {
        if (address(this).balance < _PRE_DEPOSIT_VALUE) {
            revert BufferedEtherNotEnough();
        }
        bytes32 withdrawalCredentials = _getWithdrawalCredentials();
        _doDeposit(pubkey, withdrawalCredentials, signature, _PRE_DEPOSIT_VALUE);

        // update pre deposit validators
        _addUint(_PRE_DEPOSIT_VALIDATORS_KEY, 1);
        // update buffered ether
        _subUint(_BUFFERED_ETHER_KEY, _PRE_DEPOSIT_VALUE);

        // emit event
        emit LogPreActivateValidator(operator, pubkey, _PRE_DEPOSIT_VALUE);
    }

    // receive ETH rewards from RewardsVault
    function receiveRewards() external payable {
        // update buffered ether
        _addUint(_BUFFERED_ETHER_KEY, msg.value);
        emit LogReceiveRewards(msg.value);
    }

    // handle oracle report
    // 需要更新_BEACON_ACTIVE_VALIDATORS_KEY
    // todo 结构体化参数
    function handleOracleReport(
        uint256 epochId,
        uint256 beaconValidators,
        uint256 beaconBalance,
        uint256 availableRewards,
        uint256 exitedValidators,
        uint256 burnedPEthAmount,
        uint256 lastRequestIdToBeFulfilled,
        uint256 ethAmountToLock
    ) external onlyDawnPoolOracle {
        if (beaconValidators + exitedValidators > _getUint(_DEPOSITED_VALIDATORS_KEY)) {
            revert InvalidValidators(beaconValidators, exitedValidators, _getUint(_DEPOSITED_VALIDATORS_KEY));
        }
        if (availableRewards > _getContractAddress(_REWARDS_VAULT_CONTRACT_NAME).balance) {
            revert RewardsVaultBalanceNotEnough();
        }
        if (
            beaconBalance.add(availableRewards) <=
            _getUint(_BEACON_ACTIVE_VALIDATOR_BALANCE_KEY).add(
                beaconValidators.add(exitedValidators).sub(_getUint(_BEACON_ACTIVE_VALIDATORS_KEY)).mul(
                    _DEPOSIT_VALUE_PER_VALIDATOR
                )
            )
        ) {
            revert Unprofitable();
        }

        uint256 rewards = beaconBalance.add(availableRewards).sub(
            _getUint(_BEACON_ACTIVE_VALIDATOR_BALANCE_KEY).add(
                beaconValidators.add(exitedValidators).sub(_getUint(_BEACON_ACTIVE_VALIDATORS_KEY)).mul(
                    _DEPOSIT_VALUE_PER_VALIDATOR
                )
            )
        );

        uint256 preTotalEther = _getTotalPooledEther();
        uint256 preTotalPEth = totalSupply();

        emit LogETHRewards(epochId, _getUint(_BEACON_ACTIVE_VALIDATOR_BALANCE_KEY), beaconBalance, availableRewards);

        // store beacon balance and validators
        _setUint(_BEACON_ACTIVE_VALIDATORS_KEY, beaconValidators);
        _setUint(_BEACON_ACTIVE_VALIDATOR_BALANCE_KEY, beaconBalance);
        // update deposited validators
        _subUint(_DEPOSITED_VALIDATORS_KEY, exitedValidators);

        // claim availableRewards from RewardsVault
        if (availableRewards > 0) {
            IRewardsVault(_getContractAddress(_REWARDS_VAULT_CONTRACT_NAME)).withdrawRewards(availableRewards);
        }

        // calculate rewardsPEth
        // rewardsPEth / (rewards * fee/basic) = preTotalPEth / (preTotalEther + rewards * (basic - fee)/basic)
        // rewardsPEth / (rewards * fee) = preTotalPEth / (preTotalEther * basic + rewards * (basic - fee))
        // rewardsPEth = preTotalPEth * rewards * fee / (preTotalEther * basic + rewards * (basic - fee))
        uint256 rewardsPEth = preTotalPEth.mul(rewards).mul(_getUint(_FEE_KEY)).div(
            preTotalEther.mul(_FEE_BASIC).add(rewards.mul(_FEE_BASIC.sub(_getUint(_FEE_KEY))))
        );
        _mint(address(this), rewardsPEth);
        // distributeRewards
        _distributeRewards(rewardsPEth);

        emit LogTokenRebase(epochId, preTotalEther, preTotalPEth, _getTotalPooledEther(), totalSupply());

        // process withdraw request
        if (ethAmountToLock > 0) {
            _processWithdrawRequest(lastRequestIdToBeFulfilled, ethAmountToLock);
        }

        // process burn pEth
        if (burnedPEthAmount > 0) {
            _processPEthBurnRequest(burnedPEthAmount);
        }
    }

    function preCalculateExchangeRate(
        uint256 beaconValidators,
        uint256 beaconBalance,
        uint256 availableRewards,
        uint256 exitedValidators
    ) external view returns (uint256 totalEther, uint256 totalPEth) {
        totalEther = _getUint(_BUFFERED_ETHER_KEY) // buffered balance
        .add(availableRewards)
        .add(beaconBalance) // beacon balance
            .add(
                _getUint(_DEPOSITED_VALIDATORS_KEY).sub(exitedValidators).sub(beaconValidators).mul(
                    _DEPOSIT_VALUE_PER_VALIDATOR
                )
            )
            .add(_getUint(_PRE_DEPOSIT_VALIDATORS_KEY).mul(_PRE_DEPOSIT_VALUE))
            .sub(_getUint(_UNREACHABLE_ETHER_COUNT_KEY)); // transient balance // pre validator balance // unreachable ether

        // negative reward
        if (
            beaconBalance.add(availableRewards) <=
            _getUint(_BEACON_ACTIVE_VALIDATOR_BALANCE_KEY).add(
                beaconValidators.add(exitedValidators).sub(_getUint(_BEACON_ACTIVE_VALIDATORS_KEY)).mul(
                    _DEPOSIT_VALUE_PER_VALIDATOR
                )
            )
        ) {
            totalPEth = totalSupply();
            return (totalEther, totalPEth);
        }

        uint256 rewards = beaconBalance.add(availableRewards).sub(
            _getUint(_BEACON_ACTIVE_VALIDATOR_BALANCE_KEY).add(
                beaconValidators.add(exitedValidators).sub(_getUint(_BEACON_ACTIVE_VALIDATORS_KEY)).mul(
                    _DEPOSIT_VALUE_PER_VALIDATOR
                )
            )
        );

        uint256 preTotalEther = _getTotalPooledEther();
        uint256 preTotalPEth = totalSupply();

        uint256 rewardsPEth = preTotalPEth.mul(rewards).mul(_getUint(_FEE_KEY)).div(
            preTotalEther.mul(_FEE_BASIC).add(rewards.mul(_FEE_BASIC.sub(_getUint(_FEE_KEY))))
        );

        totalPEth = preTotalPEth + rewardsPEth;
    }

    // process withdraw request
    function _processWithdrawRequest(uint256 lastRequestIdToBeFulfilled, uint256 ethAmountToLock) internal {
        if (ethAmountToLock > _getUint(_BUFFERED_ETHER_KEY)) {
            revert InvalidLockEth(ethAmountToLock);
        }
        IDawnWithdraw(_getContractAddress(_DAWN_WITHDRAW_CONTRACT_NAME)).checkFulfillment(
            lastRequestIdToBeFulfilled,
            ethAmountToLock
        );
        // lock ETH for withdraw: transfer ETH to DawnWithdraw
        _subUint(_BUFFERED_ETHER_KEY, ethAmountToLock);
        IDawnWithdraw(_getContractAddress(_DAWN_WITHDRAW_CONTRACT_NAME)).fulfillment{value: ethAmountToLock}(
            lastRequestIdToBeFulfilled
        );
    }

    // process burn pEth
    function _processPEthBurnRequest(uint256 burnedPEthAmount) internal {
        address burnerAddr = _getContractAddress(_BURNER_CONTRACT_NAME);
        if (burnedPEthAmount > balanceOf(burnerAddr))
            revert ErrorBurnedPEthAmount(burnedPEthAmount, balanceOf(burnerAddr));
        _burn(burnerAddr, burnedPEthAmount);
        IBurner(burnerAddr).commitPEthToBurn(burnedPEthAmount);
    }

    function punish(address burnAddress, uint256 pethAmountToBurn) external onlyNodeManager {
        _punish(burnAddress, pethAmountToBurn);
    }

    function punish(
        address burnAddress,
        uint256 pethAmountToBurn,
        uint256 ethAmountToDecrease
    ) external onlyNodeManager {
        _punish(burnAddress, pethAmountToBurn, ethAmountToDecrease);
    }

    function increaseUnreachableEtherCount(uint256 amount) public onlyBurner {
        _addUint(_UNREACHABLE_ETHER_COUNT_KEY, amount);
        emit LogDecreaseEther(amount);
    }

    function _punish(address burnAddress, uint256 pethAmountToBurn) internal {
        if (pethAmountToBurn == 0) revert ZeroBurnAmount();
        if (balanceOf(burnAddress) < pethAmountToBurn) revert PEthNotEnough();

        _transfer(burnAddress, _getContractAddress(_BURNER_CONTRACT_NAME), pethAmountToBurn);
        IBurner(_getContractAddress(_BURNER_CONTRACT_NAME)).requestBurnPEth(burnAddress, pethAmountToBurn);

        emit LogPunish(burnAddress, pethAmountToBurn);
    }

    function _punish(address burnAddress, uint256 pethAmountToBurn, uint256 ethAmountToDecrease) internal {
        if (pethAmountToBurn == 0) revert ZeroBurnAmount();
        if (balanceOf(burnAddress) < pethAmountToBurn) revert PEthNotEnough();

        _transfer(burnAddress, _getContractAddress(_BURNER_CONTRACT_NAME), pethAmountToBurn);
        IBurner(_getContractAddress(_BURNER_CONTRACT_NAME)).requestBurnPEthAndDecreaseEth(
            burnAddress,
            pethAmountToBurn,
            ethAmountToDecrease
        );

        emit LogPunishWithEth(burnAddress, pethAmountToBurn, ethAmountToDecrease);
    }

    function getBeaconStat()
        external
        view
        returns (
            uint256 preDepositValidators,
            uint256 depositedValidators,
            uint256 beaconValidators,
            uint256 beaconBalance
        )
    {
        preDepositValidators = _getUint(_PRE_DEPOSIT_VALIDATORS_KEY);
        depositedValidators = _getUint(_DEPOSITED_VALIDATORS_KEY);
        beaconValidators = _getUint(_BEACON_ACTIVE_VALIDATORS_KEY);
        beaconBalance = _getUint(_BEACON_ACTIVE_VALIDATOR_BALANCE_KEY);
    }

    function getBufferedEther() external view returns (uint256) {
        return _getUint(_BUFFERED_ETHER_KEY);
    }

    // ***************** public function *****************

    // calculate the amount of pETH backing an amount of ETH
    function getEtherByPEth(uint256 pEthAmount) public view returns (uint256) {
        uint256 totalPEth = totalSupply();
        if (totalPEth == 0) return 0;

        uint256 totalEther = _getTotalPooledEther();
        return totalEther.mul(pEthAmount).div(totalPEth);
    }

    // calculate the amount of ETH backing an amount of pETH
    function getPEthByEther(uint256 ethAmount) public view returns (uint256) {
        uint256 totalEther = _getTotalPooledEther();
        if (totalEther == 0) return 0;

        uint256 totalPEth = totalSupply();
        return totalPEth.mul(ethAmount).div(totalEther);
    }

    // get DawnPool protocol total value locked
    function getTotalPooledEther() public view returns (uint256) {
        return _getTotalPooledEther();
    }

    function _getTotalPooledEther() internal view returns (uint256) {
        return
            _getUint(_BUFFERED_ETHER_KEY) // buffered balance
            .add(_getUint(_BEACON_ACTIVE_VALIDATOR_BALANCE_KEY)) // beacon balance
                .add(
                    _getUint(_DEPOSITED_VALIDATORS_KEY).sub(_getUint(_BEACON_ACTIVE_VALIDATORS_KEY)).mul(
                        _DEPOSIT_VALUE_PER_VALIDATOR
                    )
                )
                .add(_getUint(_PRE_DEPOSIT_VALIDATORS_KEY).mul(_PRE_DEPOSIT_VALUE))
                .sub(_getUint(_UNREACHABLE_ETHER_COUNT_KEY)); // transient balance // pre validator balance // unreachable ether
    }

    // ***************** internal function *****************

    // distribute pETH rewards to NodeOperators、DawnInsurance、DawnTreasury
    function _distributeRewards(uint256 rewardsPEth) internal {
        uint256 insuranceFee = _getUint(_INSURANCE_FEE_KEY);
        uint256 nodeOperatorFee = _getUint(_NODE_OPERATOR_FEE_KEY);

        uint256 nodeOperatorRewards = rewardsPEth.mul(nodeOperatorFee).div(_FEE_BASIC);
        uint256 insuranceRewards = rewardsPEth.mul(insuranceFee).div(_FEE_BASIC);
        uint256 treasuryRewards = rewardsPEth.sub(nodeOperatorRewards).sub(insuranceRewards);

        _transferToInsurance(insuranceRewards);
        _transferToTreasury(treasuryRewards);
        _distributeNodeOperatorRewards(nodeOperatorRewards);
    }

    // transfer pETH as rewards to DawnInsurance
    function _transferToInsurance(uint256 rewardsPEth) internal {
        _transfer(address(this), _getContractAddress(_INSURANCE_CONTRACT_NAME), rewardsPEth);
    }

    // transfer pETH as rewards to DawnTreasury
    function _transferToTreasury(uint256 rewardsPEth) internal {
        _transfer(address(this), _getContractAddress(_TREASURY_CONTRACT_NAME), rewardsPEth);
    }

    // distribute pETH as rewards to NodeOperators
    function _distributeNodeOperatorRewards(uint256 rewardsPEth) internal {
        address nodeManagerAddr = _getContractAddress(_NODE_OPERATOR_REGISTER_CONTRACT_NAME);
        IDepositNodeManager nodeManager = IDepositNodeManager(nodeManagerAddr);

        if (nodeManager.getTotalActivatedValidatorsCount() > 0) {
            _transfer(address(this), nodeManagerAddr, rewardsPEth);
            nodeManager.distributeNodeOperatorRewards(rewardsPEth);
        }
    }

    function _stake() internal returns (uint256) {
        if (msg.value == 0) {
            revert StakeZeroEther();
        }

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

    function _toLittleEndian64(uint256 value) internal pure returns (uint256 result) {
        result = 0;
        uint256 tempValue = value;
        for (uint256 i = 0; i < 8; ++i) {
            result = (result << 8) | (tempValue & 0xFF);
            tempValue >>= 8;
        }

        assert(0 == tempValue); // fully converted
        result <<= (24 * 8);
    }

    function _doDeposit(
        bytes calldata pubkey,
        bytes32 withdrawalCredentials,
        bytes calldata signature,
        uint256 amount
    ) internal {
        uint256 depositAmount = amount / 1 gwei;
        // Compute deposit data root (`DepositData` hash tree root) according to deposit_contract.sol
        bytes32 pubkeyRoot = sha256(abi.encodePacked(pubkey, bytes16(0)));
        bytes32 signatureRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(signature[:64])),
                sha256(abi.encodePacked(signature[64:], bytes32(0)))
            )
        );
        bytes32 depositDataRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(pubkeyRoot, withdrawalCredentials)),
                sha256(abi.encodePacked(_toLittleEndian64(depositAmount), signatureRoot))
            )
        );
        IDepositContract(_getDepositContract()).deposit{value: amount}(
            pubkey,
            abi.encodePacked(withdrawalCredentials),
            signature,
            depositDataRoot
        );
    }

    function getWithdrawalCredentials() external view returns (bytes32) {
        return _getWithdrawalCredentials();
    }

    function _getWithdrawalCredentials() internal view returns (bytes32) {
        address rewardsVault = _getContractAddress(_REWARDS_VAULT_CONTRACT_NAME);
        return bytes32(bytes.concat(bytes12(_WITHDRAWAL_PREFIX), bytes20(rewardsVault)));
    }

    function _getDepositContract() internal view returns (address) {
        return _getContractAddress(_DEPOSIT_CONTRACT_NAME);
    }

    // // ***************** modifier *****************

    modifier onlyActiveNodeOperator(address operator) {
        (address nodeAddress, bool isActive) = IDepositNodeManager(_getContractAddress(_DEPOSIT_NODE_MANAGER))
            .getNodeOperator(operator);
        if (msg.sender != nodeAddress) {
            revert CallerAuthFailed(msg.sender);
        }
        if (!isActive) {
            revert NodeOperatorInactive(nodeAddress);
        }
        _;
    }

    modifier onlyNodeManager() {
        if (msg.sender != _getContractAddress(_NODE_OPERATOR_REGISTER_CONTRACT_NAME)) {
            revert CallerAuthFailed(msg.sender);
        }
        _;
    }

    modifier onlyDawnPoolOracle() {
        if (msg.sender != _getContractAddress(_ORACLE_CONTRACT_NAME)) {
            revert CallerAuthFailed(msg.sender);
        }
        _;
    }

    modifier onlyBurner() {
        if (msg.sender != _getContractAddress(_BURNER_CONTRACT_NAME)) {
            revert CallerAuthFailed(msg.sender);
        }
        _;
    }
}
