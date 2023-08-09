// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

library ReportUtils {
    // 掩码，用于提取计数器相关的位
    uint256 internal constant _COUNT_OUTMASK = 0xFFFFFFFFFFFFFFFFFFFFFFFF0000;

//    function encode(uint64 beaconBalance, uint32 beaconValidators) internal pure returns (uint256) {
//        return (uint256(beaconBalance) << 48) | (uint256(beaconValidators) << 16);
//    }

//    function decode(uint256 value) internal pure returns (uint64 beaconBalance, uint32 beaconValidators) {
//        beaconBalance = uint64(value >> 48);
//        beaconValidators = uint32(value >> 16);
//    }

    function encode(uint256 paramA, uint256 paramB) internal pure returns (uint256) {
        return (paramA | paramB);
    }

    function decode(uint256 encodedValue) internal pure returns (uint256, uint256) {
        uint256 paramA = encodedValue & uint256((2**128) - 1); // 提取低 128 位
        uint256 paramB = encodedValue >> 128; // 提取高 128 位

        return (paramA, paramB);
    }

    function decodeWithCount(
        uint256 value
    ) internal pure returns (uint64 beaconBalance, uint32 beaconValidators, uint16 count) {
        beaconBalance = uint64(value >> 48);
        beaconValidators = uint32(value >> 16);
        count = uint16(value);
    }

    /// @notice Check if the given reports are different, not considering the counter of the first
    function isDifferent(uint256 value, uint256 that) internal pure returns (bool) {
        return (value & _COUNT_OUTMASK) != that;
    }

    function getCount(uint256 value) internal pure returns (uint16) {
        return uint16(value);
    }
}
