// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDepositNodeOperator.sol";
import "../interface/IDawnDeposit.sol";
import "../interface/IDepositNodeManager.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";
import "../base/DawnBase.sol";
import "../interface/IDepositContract.sol";

contract DepositNodeOperator is IDepositNodeOperator, DawnBase {
    uint64 internal constant PUBKEY_LENGTH = 48;
    uint64 internal constant SIGNATURE_LENGTH = 96;

    constructor(address operator, IDawnStorageInterface dawnStorage) DawnBase(dawnStorage){
        setAddress(_getOperatorStorageKey(), operator);
    }

    function getOperator() public view returns (address) {
        return getAddress(_getOperatorStorageKey());
    }

    function addValidators(bytes calldata pubkeys, bytes calldata signatures) external payable returns (uint256 startIndex, uint256 count) {
        require(msg.sender == getOperator(), "Only operator can add validators!");
        require(pubkeys.length % PUBKEY_LENGTH == 0, "Inconsistent public keys len!");
        require(signatures.length % SIGNATURE_LENGTH == 0, "Inconsistent signatures len!");
        count = pubkeys.length / PUBKEY_LENGTH;
        require(signatures.length / SIGNATURE_LENGTH == count, "Inconsistent signatures count!");
        uint256 minAmount = _getMinOperatorStakingAmount();
        require(msg.value == minAmount * count, "Inconsistent deposits!");
        startIndex = IDepositNodeManager(_getDepositNodeManager()).registerValidators(msg.sender, count);
        bytes32 withdrawalCredentials = _getWithdrawalCredentials();
        for(uint256 i = 0; i < count; ++i) {
            bytes memory pubkey = BytesLib.slice(pubkeys, i * PUBKEY_LENGTH, PUBKEY_LENGTH);
            bytes memory signature = BytesLib.slice(signatures, i * SIGNATURE_LENGTH, SIGNATURE_LENGTH);
            bytes memory signingKey = BytesLib.concat(pubkey, signature);
            setBytes(_getStorageKeyByValidatorIndex(startIndex + i), signingKey);
            _deposit(pubkey, signature, minAmount, withdrawalCredentials);
        }

    }

    function _getStorageKeyByValidatorIndex(uint256 index) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeOperator.signingKey", index));
    }

    function _getMinOperatorStakingAmount() internal view returns (uint256) {
        return 2 ether; // TODO where to get
    }

    /**
    * @dev Padding memory array with zeroes up to 64 bytes on the right
    * @param _b Memory array of size 32 .. 64
    */
    function _pad64(bytes memory _b) internal pure returns (bytes memory) {
        assert(_b.length >= 32 && _b.length <= 64);
        if (64 == _b.length)
            return _b;

        bytes memory zero32 = new bytes(32);
        assembly { mstore(add(zero32, 0x20), 0) }

        if (32 == _b.length)
            return BytesLib.concat(_b, zero32);
        else
            return BytesLib.concat(_b, BytesLib.slice(zero32, 0, uint256(64) - _b.length));
    }

    /**
    * @dev Converting value to little endian bytes and padding up to 32 bytes on the right
    * @param _value Number less than `2**64` for compatibility reasons
    */
    function _toLittleEndian64(uint256 _value) internal pure returns (uint256 result) {
        result = 0;
        uint256 temp_value = _value;
        for (uint256 i = 0; i < 8; ++i) {
            result = (result << 8) | (temp_value & 0xFF);
            temp_value >>= 8;
        }

        assert(0 == temp_value);    // fully converted
        result <<= (24 * 8);
    }

    function _deposit(bytes memory pubkey, bytes memory signature, uint256 amount, bytes32 withdrawalCredentials) internal {
        // Compute deposit data root (`DepositData` hash tree root) according to deposit_contract.sol
        bytes32 pubkeyRoot = sha256(_pad64(pubkey));
        bytes32 signatureRoot = sha256(
            abi.encodePacked(
                sha256(BytesLib.slice(signature, 0, 64)),
                sha256(_pad64(BytesLib.slice(signature, 64, SIGNATURE_LENGTH - 64)))
            )
        );
        bytes32 depositDataRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(pubkeyRoot, withdrawalCredentials)),
                sha256(abi.encodePacked(_toLittleEndian64(amount), signatureRoot))
            )
        );
        uint256 targetBalance = address(this).balance - amount;
        IDepositContract(_getDepositContract()).deposit{ value: amount }(
            pubkey, abi.encodePacked(withdrawalCredentials), signature, depositDataRoot);
        require(address(this).balance == targetBalance, "Expecting deposit to happen!");
    }

    function _getDawnDeposit() internal view returns (address) {
        return getContractAddressUnsafe("DawnDeposit");
    }

    function _getDepositNodeManager() internal view returns (address) {
        return getContractAddressUnsafe("DepositNodeManager");
    }

    function _getDepositContract() internal view returns (address) {
        return getContractAddressUnsafe("DepositContract");
    }

    function _getWithdrawalCredentials() internal view returns (bytes32) {
        return getBytes32("WithdrawalCredentials"); // TODO confirm
    }

    function _getOperatorStorageKey() internal view returns (bytes32) {
        return keccak256(abi.encodePacked("DepositNodeOperator.operator", address(this)));
    }
}
