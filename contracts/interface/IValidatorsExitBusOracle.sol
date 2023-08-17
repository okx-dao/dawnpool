// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

interface IValidatorsExitBusOracle {

    event BeaconSpecSet(uint64 epochsPerFrame, uint64 slotsPerEpoch, uint64 secondsPerSlot, uint64 genesisTime);
    event ExpectedEpochIdUpdated(uint256 epochId);

    // 验证者退出请求事件
    event ValidatorExitRequest(
        // 表示在此报告中相关联的验证器退出请求的总数
        uint256 requestsCount,
        // 验证器退出的索引数组
        uint256[] indexes,
        // 验证器发出请求的时间戳
        uint256 timestamp
    );

    /**
     * @notice Return the current reporting array size
     */
    function getCurrentReportVariantsSize() external view returns (uint256);

    /**
     * Updates beacon specification data
     */
    function setBeaconSpec(
        uint64 epochsPerFrame,
        uint64 slotsPerEpoch,
        uint64 secondsPerSlot,
        uint64 genesisTime
    ) external;

    /**
     * Returns the epoch calculated from current timestamp
     */
    function getCurrentEpochId() external view returns (uint256);

    function getLastProcessingRefSlot() external view returns (uint256);

    function getLastProcessingRefEpoch() external view returns (uint256);

    function initialize(
        uint64 epochsPerFrame,
        uint64 slotsPerEpoch,
        uint64 secondsPerSlot,
        uint64 genesisTime,
        uint256 lastProcessingRefSlot
    ) external;

}
