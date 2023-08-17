// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

library ReportUtils {
    // 掩码，用于提取计数器相关的位
    uint256 internal constant _COUNT_OUTMASK = 0xFFFFFFFFFFFFFFFFFFFFFFFF0000;

    function encode(uint64 paramA, uint32 paramB) internal pure returns (uint256) {
        return (uint256(paramA) << 48) | (uint256(paramB) << 16);
    }

    function decode(uint256 value) internal pure returns (uint64 beaconBalance, uint32 beaconValidators) {
        beaconBalance = uint64(value >> 48);
        beaconValidators = uint32(value >> 16);
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
