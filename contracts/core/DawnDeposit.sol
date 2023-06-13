// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDawnDeposit.sol";
import "../token/DawnTokenPETH.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../base/DawnBase.sol";
import "../interface/IDepositNodeManager.sol";
import "../interface/IRewardsVault.sol";
import "../deposit_contract/deposit_contract.sol";

interface NodeManager {
    function distributeNodeOperatorRewards(uint256 pethAmount) external;
}

contract DawnDeposit is IDawnDeposit, DawnTokenPETH, DawnBase {
    using SafeMath for uint256;

    uint256 public constant DEPOSIT_VALUE_PER_VALIDATOR = 32 ether;
    uint256 public constant PRE_DEPOSIT_VALUE = 1 ether;
    uint256 public constant POST_DEPOSIT_VALUE = 31 ether;
    uint256 internal constant _FEE_BASIC = 10000;

    bytes32 internal constant _BUFFERED_ETHER_KEY = keccak256("dawnDeposit.bufferedEther");
    bytes32 internal constant _PRE_DEPOSIT_VALIDATORS_KEY = keccak256("dawnDeposit.preDepositValidators");
    bytes32 internal constant _DEPOSITED_VALIDATORS_KEY = keccak256("dawnDeposit.depositedValidators");
    bytes32 internal constant _BEACON_ACTIVE_VALIDATORS_KEY = keccak256("dawnDeposit.beaconActiveValidators");
    bytes32 internal constant _BEACON_ACTIVE_VALIDATOR_BALANCE_KEY = keccak256("dawnDeposit.beaconActiveValidatorBalance");

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
        require(msg.sender == _getContractAddress(_INSURANCE_CONTRACT_NAME), "receive not from insurance");

        // burn insurance's pEth
        _burn(_getContractAddress(_INSURANCE_CONTRACT_NAME), pEthAmount);

        emit LogReceiveInsurance(pEthAmount);
    }

    // deposit 31 ETH to activate validator
    function activateValidator(
        address operator,
        bytes calldata pubkey,
        bytes calldata signature
    ) external onlyActiveNodeOperator(operator) {
        require(address(this).balance >= POST_DEPOSIT_VALUE, "buffer ether not enough");
        bytes32 withdrawalCredentials =  _getWithdrawalCredentials();
        _doDeposit(pubkey, withdrawalCredentials, signature, POST_DEPOSIT_VALUE);

        // update deposited validators
        _addUint(_DEPOSITED_VALIDATORS_KEY, 1);
        // update pre deposit validators
        _subUint(_PRE_DEPOSIT_VALIDATORS_KEY, 1);
        // update buffered ether
        _subUint(_BUFFERED_ETHER_KEY, POST_DEPOSIT_VALUE);

        // emit event
        emit LogActivateValidator(operator, pubkey, POST_DEPOSIT_VALUE);
    }

    // deposit 1 ETH for NodeOperatorRegister
    function preActivateValidator(
        address operator,
        bytes calldata pubkey,
        bytes calldata signature
    ) external onlyActiveNodeOperator(operator) {
        require(address(this).balance >= PRE_DEPOSIT_VALUE, "buffer ether not enough");
        bytes32 withdrawalCredentials =  _getWithdrawalCredentials();
        _doDeposit(pubkey, withdrawalCredentials, signature, PRE_DEPOSIT_VALUE);

        // update pre deposit validators
        _addUint(_PRE_DEPOSIT_VALIDATORS_KEY, 1);
        // update buffered ether
        _subUint(_BUFFERED_ETHER_KEY, PRE_DEPOSIT_VALUE);

        // emit event
        emit LogPreActivateValidator(operator, pubkey, PRE_DEPOSIT_VALUE);
    }

    // receive ETH rewards from RewardsVault
    function receiveRewards() external payable {
        // update buffered ether
        _addUint(_BUFFERED_ETHER_KEY, msg.value);
        emit LogReceiveRewards(msg.value);
    }

    // handle oracle report
    // 需要更新_BEACON_ACTIVE_VALIDATORS_KEY
    function handleOracleReport(
        uint256 epochId,
        uint256 beaconValidators,
        uint256 beaconBalance,
        uint256 availableRewards,
        uint256 exitedValidators
    ) external {
        require(msg.sender == _getContractAddress(_ORACLE_CONTRACT_NAME), "only call by DawnPoolOracle");
        require(
            availableRewards <= _getContractAddress(_REWARDS_VAULT_CONTRACT_NAME).balance,
            "RewardsVault insufficient balance"
        );
        require(
            beaconBalance.add(availableRewards) >
                _getUint(_BEACON_ACTIVE_VALIDATOR_BALANCE_KEY).add(
                    beaconValidators.add(exitedValidators).sub(_getUint(_BEACON_ACTIVE_VALIDATORS_KEY)).mul(DEPOSIT_VALUE_PER_VALIDATOR)
                ),
            "unprofitable"
        );

        uint256 rewards = beaconBalance.add(availableRewards).sub(
            _getUint(_BEACON_ACTIVE_VALIDATOR_BALANCE_KEY).add(
                beaconValidators.add(exitedValidators).sub(_getUint(_BEACON_ACTIVE_VALIDATORS_KEY)).mul(DEPOSIT_VALUE_PER_VALIDATOR)
            )
        );

        uint256 preTotalEther = getTotalPooledEther();
        uint256 preTotalPEth = totalSupply();

        emit LogETHRewards(
            epochId,
            _getUint(_BEACON_ACTIVE_VALIDATOR_BALANCE_KEY),
            beaconBalance,
            availableRewards
        );

        // store beacon balance and validators
        _setUint(_BEACON_ACTIVE_VALIDATORS_KEY, beaconValidators);
        _setUint(_BEACON_ACTIVE_VALIDATOR_BALANCE_KEY, beaconBalance);

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
        // distributeRewards
        _distributeRewards(rewardsPEth);

        emit LogTokenRebase(
            epochId,
            preTotalEther,
            preTotalPEth,
            getTotalPooledEther(),
            totalSupply()
        );

    }

    function getBeaconStat() external view returns (uint256 depositedValidators, uint256 beaconValidators, uint256 beaconBalance) {
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
            _getUint(_BUFFERED_ETHER_KEY) // buffered balance
                .add(_getUint(_BEACON_ACTIVE_VALIDATOR_BALANCE_KEY)) // beacon balance
                .add(
                    _getUint(_DEPOSITED_VALIDATORS_KEY).sub(_getUint(_BEACON_ACTIVE_VALIDATORS_KEY)).mul(
                        DEPOSIT_VALUE_PER_VALIDATOR
                    )
                ) // transient balance
                .add(_getUint(_PRE_DEPOSIT_VALIDATORS_KEY).mul(PRE_DEPOSIT_VALUE)); // pre validator balance
    }


    // ***************** internal function *****************

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
        address nodeManagerAddr = _getContractAddress(_NODE_OPERATOR_REGISTER_CONTRACT_NAME);
        _mint(nodeManagerAddr, rewardsPEth);
        NodeManager(nodeManagerAddr).distributeNodeOperatorRewards(rewardsPEth);
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
        IDepositContract(_getDepositContract()).deposit{ value: amount }(
            pubkey, abi.encodePacked(withdrawalCredentials), signature, depositDataRoot);
    }

    function getWithdrawalCredentials() external view returns (bytes32) {
        return _getWithdrawalCredentials();
    }

    function _getWithdrawalCredentials() internal view returns (bytes32) {
        address rewardsVault = _getContractAddress(_REWARDS_VAULT_CONTRACT_NAME);
        return bytes32(bytes.concat(bytes12(0x010000000000000000000000), bytes20(rewardsVault)));
    }

    function _getDepositContract() internal view returns (address) {
        return _getContractAddress(_DEPOSIT_CONTRACT_NAME);
    }



    // // ***************** modifier *****************

    modifier onlyActiveNodeOperator(address operator) {
        (address nodeAddress, bool isActive) = IDepositNodeManager(_getContractAddress(_DEPOSIT_NODE_MANAGER)).getNodeOperator(operator);
        require(msg.sender == nodeAddress, "Only node operator can register validators!");
        require(isActive, "Node operator is inactive!");
        _;
    }
}
