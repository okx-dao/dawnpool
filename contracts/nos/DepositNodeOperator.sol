// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDepositNodeOperator.sol";
//import "../interface/IDawnDeposit.sol";
import "../interface/IDepositNodeManager.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";
import "../base/DawnBase.sol";
import "../interface/IDepositContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDawnDeposit {
    function stake() external payable returns (uint256);

    // deposit 31 ETH to activate validator
    function activateValidator(
        address operator,
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external;

    // deposit 1 ETH for NodeOperatorRegister
    function preActivateValidator(
        address operator,
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    ) external;

    function getEtherByPEth(uint256 pEthAmount) external view returns (uint256);
}

/**
 * @title Node operator contract
 * @author Ray
 * @notice Node operator add his validator pubkeys through his node operator contract
 * @dev Node operator needs to stake specified amount of ETH to add a validator through this contract
 * The staked ETH will be transferred to dawn deposit pool and the returned pETH locked in this contract
 * It will be claimable if the operator exit his validators
 * However, the "overflow" part of shares can be claimed with validator rewards
 */
contract DepositNodeOperator is IDepositNodeOperator, DawnBase {
    uint64 internal constant _PUBKEY_LENGTH = 48;
    uint64 internal constant _SIGNATURE_LENGTH = 96;
    /// @dev Deposit 1 ETH when a validator pubkey is added, so that other 1 eth can earn rewards
    uint128 internal constant _PRE_DEPOSIT_VALUE = 1 ether;

    /**
     * @dev Constructor
     * @param operator Address of node operator
     * @param dawnStorage Storage address
     */
    constructor(address operator, IDawnStorageInterface dawnStorage) DawnBase(dawnStorage) {
        require(operator != address(0), "Operator address cannot be 0x0!");
        _setAddress(_getOperatorStorageKey(), operator);
    }

    /**
     * @notice Get node operator address
     * @return Node operator address
     */
    function getOperator() public view returns (address) {
        return _getAddress(_getOperatorStorageKey());
    }

    /**
     * @notice Add stakes for operator, and any account can do this
     * @return Minted pETH amount
     */
    function addStakes() external payable returns (uint256) {
        return IDawnDeposit(_getDawnDeposit()).stake{value: msg.value}();
    }

    /**
     * @notice Add validator pubkeys and signatures
     * @dev Make sure to have enough stakes to add validators
     * @param pubkeys Public keys
     * @param signatures Signatures
     * @return startIndex The first index of validators added
     * @return count Added validators count
     */
    function addValidators(
        bytes calldata pubkeys,
        bytes calldata signatures
    ) external payable returns (uint256 startIndex, uint256 count) {
        require(msg.sender == getOperator(), "Only operator can add validators!");
        require(pubkeys.length % _PUBKEY_LENGTH == 0, "Inconsistent public keys len!");
        require(signatures.length % _SIGNATURE_LENGTH == 0, "Inconsistent signatures len!");
        count = pubkeys.length / _PUBKEY_LENGTH;
        require(signatures.length / _SIGNATURE_LENGTH == count, "Inconsistent signatures count!");
        IDawnDeposit dawnDeposit = IDawnDeposit(_getDawnDeposit());
        if (msg.value > 0) {
            dawnDeposit.stake{value: msg.value}();
        }
        uint256 operatorBalance = dawnDeposit.getEtherByPEth(IERC20(address(dawnDeposit)).balanceOf(address(this)));
        IDepositNodeManager nodeManager = IDepositNodeManager(_getDepositNodeManager());
        uint256 nextActiveValidatorsCount = getActiveValidatorsCount() + count;
        uint256 requiredAmount = nodeManager.getMinOperatorStakingAmount() * nextActiveValidatorsCount;
        require(operatorBalance >= requiredAmount, "Not enough deposits!");
        startIndex = nodeManager.registerValidators(msg.sender, count);
        bytes32 withdrawalCredentials = getWithdrawalCredentials();
        for (uint256 i = 0; i < count; ++i) {
            bytes memory pubkey = BytesLib.slice(pubkeys, i * _PUBKEY_LENGTH, _PUBKEY_LENGTH);
            bytes memory signature = BytesLib.slice(signatures, i * _SIGNATURE_LENGTH, _SIGNATURE_LENGTH);
            bytes memory signingKey = BytesLib.concat(pubkey, signature);
            _setBytes(_getStorageKeyByValidatorIndex(startIndex + i), signingKey);
            _deposit(dawnDeposit, pubkey, signature, _PRE_DEPOSIT_VALUE, withdrawalCredentials);
            emit SigningKeyAdded(startIndex + i, pubkey);
        }
        _setUint(_getActiveValidatorsCountStorageKey(), nextActiveValidatorsCount);
    }

    /**
     * @notice Get active validators of node operator, including includes all status, except exited
     * @return Active validators count
     */
    function getActiveValidatorsCount() public view returns (uint256) {
        return _getUint(_getActiveValidatorsCountStorageKey());
    }

    /**
     * @notice Get validating validators of node operator, only VALIDATING
     * @return Active validators count
     */
    function getValidatingValidatorsCount() external view returns (uint256) {
        return _getUint(_getValidatingValidatorsCountStorageKey());
    }

    /**
     * @notice Get WithdrawalCredentials
     */
    function getWithdrawalCredentials() public view returns (bytes32) {
        address rewardsVault = _getContractAddress("RewardsVault");
        return bytes32(bytes.concat(bytes12(0x010000000000000000000000), bytes20(rewardsVault)));
    }

    /// @dev Get the storage key of the validator signingKey
    function _getStorageKeyByValidatorIndex(uint256 index) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeOperator.signingKey", index));
    }

    /**
     * @dev Padding memory array with zeroes up to 64 bytes on the right
     * @param b Memory array of size 32 .. 64
     */
    function _pad64(bytes memory b) internal pure returns (bytes memory) {
        assert(b.length >= 32 && b.length <= 64);
        if (64 == b.length) return b;

        bytes memory zero32 = new bytes(32);
        assembly {
            mstore(add(zero32, 0x20), 0)
        }

        if (32 == b.length) return BytesLib.concat(b, zero32);
        else return BytesLib.concat(b, BytesLib.slice(zero32, 0, uint256(64) - b.length));
    }

    /**
     * @dev Converting value to little endian bytes and padding up to 32 bytes on the right
     * @param value Number less than `2**64` for compatibility reasons
     */
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

    /**
     * @dev Calculate the deposit data root and call dawn deposit contract to deposit
     * @param dawnDeposit Deposit contract interface
     * @param pubkey Public key to deposit
     * @param signature Signature to deposit
     * @param amount Deposit amount
     * It should be 1 ETH when add a public key
     * Instead 31 ETH when activate
     * @param withdrawalCredentials Withdrawal credentials
     */
    function _deposit(
        IDawnDeposit dawnDeposit,
        bytes memory pubkey,
        bytes memory signature,
        uint256 amount,
        bytes32 withdrawalCredentials
    ) internal {
        // Compute deposit data root (`DepositData` hash tree root) according to deposit_contract.sol
        bytes32 pubkeyRoot = sha256(_pad64(pubkey));
        bytes32 signatureRoot = sha256(
            abi.encodePacked(
                sha256(BytesLib.slice(signature, 0, 64)),
                sha256(_pad64(BytesLib.slice(signature, 64, _SIGNATURE_LENGTH - 64)))
            )
        );
        bytes32 depositDataRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(pubkeyRoot, withdrawalCredentials)),
                sha256(abi.encodePacked(_toLittleEndian64(amount), signatureRoot))
            )
        );
        //        IDepositContract(_getDepositContract()).deposit{ value: amount }(
        //            pubkey, abi.encodePacked(withdrawalCredentials), signature, depositDataRoot);
        dawnDeposit.preActivateValidator(msg.sender, pubkey, signature, depositDataRoot);
    }

    /// @dev Get address of dawn deposit contract
    function _getDawnDeposit() internal view returns (address) {
        return _getContractAddressUnsafe("DawnDeposit");
    }

    /// @dev Get DepositNodeManager contract address
    function _getDepositNodeManager() internal view returns (address) {
        return _getContractAddressUnsafe("DepositNodeManager");
    }

    /// @dev Get the operator storage key
    function _getOperatorStorageKey() internal view returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeOperator.operator", address(this)));
    }

    /// @dev Get active validators count storage key
    function _getActiveValidatorsCountStorageKey() internal view returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeOperator.ACTIVE_VALIDATORS_COUNT", getOperator()));
    }

    /// @dev Get validating validators count storage key, only VALIDATING status
    function _getValidatingValidatorsCountStorageKey() internal view returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeOperator.VALIDATING_VALIDATORS_COUNT", getOperator()));
    }
}
