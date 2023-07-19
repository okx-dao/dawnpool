// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;



interface IValidatorsExitBusOracle {

    event QuorumChanged(uint256 quorum);
    event BeaconSpecSet(
        uint64 epochsPerFrame,
        uint64 slotsPerEpoch,
        uint64 secondsPerSlot,
        uint64 genesisTime
    );

    event MemberAdded(address member);
    event ExpectedEpochIdUpdated(uint256 epochId);

    // 验证者退出请求事件
    event ValidatorExitRequest(
    // 表示在此报告中相关联的验证器退出请求的总数
        uint256 requestsCount,
    // 验证器发出请求的时间戳
        uint256 timestamp
    );

    /**
     * @notice Return the number of exactly the same reports needed to finalize the epoch
     */
    function getQuorum() external view returns (uint256);

    /**
 * @notice Return the current reporting array size
     */
    function getCurrentReportVariantsSize() external view returns (uint256);

    /**
 * @notice Return the current reporting array element with the given index
     */
    function getCurrentReportVariant(uint256 _index)
    external
    view
    returns (
        uint64 beaconBalance,
        uint32 beaconValidators,
        uint16 count
    );

    /**
 * @notice Return the current oracle member committee list
     */
    function getOracleMembers() external view returns (address[] memory);

    /**
 * Updates beacon specification data
 */
    function setBeaconSpec(
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime
    )
    external;

    /**
 * Returns the epoch calculated from current timestamp
 */
    function getCurrentEpochId() external view returns (uint256);

    /**
 * @notice Set the number of exactly the same reports needed to finalize the epoch to `_quorum`
     */
    function setQuorum(uint256 _quorum) external;


    function getLastProcessingRefSlot() external view returns (uint256);

    function getLastProcessingRefEpoch() external view returns (uint256);

    function initialize(
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime,
        uint256 lastProcessingRefSlot
    ) external;

    /**
 * @notice Add `_member` to the oracle member committee list
     */
    function addOracleMember(address _member) external;

}
