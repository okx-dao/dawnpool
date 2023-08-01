// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "../interface/IDawnDeposit.sol";

interface IDawnPoolOracle {
    event BeaconReportReceiverSet(address callback);
    event MemberAdded(address member);
    event MemberRemoved(address member);
    event QuorumChanged(uint256 quorum);
    event ExpectedEpochIdUpdated(uint256 epochId);
    event BeaconSpecSet(uint64 epochsPerFrame, uint64 slotsPerEpoch, uint64 secondsPerSlot, uint64 genesisTime);
    event BeaconReported(
        uint256 epochId,
        uint256 beaconBalance,
        uint256 beaconValidators,
        uint256 rewardsVaultBalance,
        uint256 exitedValidators,
        uint256 burnedPEthAmount,
        uint256 lastRequestIdToBeFulfilled,
        uint256 ethAmountToLock,
        address caller
    );
    event Completed(
        uint256 epochId,
        uint256 beaconValidators,
        uint256 beaconBalance,
        uint256 rewardsVaultBalance,
        uint256 exitedValidators,
        uint256 burnedPEthAmount,
        uint256 lastRequestIdToBeFulfilled,
        uint256 ethAmountToLock
    );

    /**
     * @notice Return the DawnPool contract address
     */
    function getDawnDeposit() external view returns (IDawnDeposit);

    /**
     * @notice Return the number of exactly the same reports needed to finalize the epoch
     */
    function getQuorum() external view returns (uint256);

    /**
     * @notice Return the receiver contract address to be called when the report is pushed to Lido
     */
    function getBeaconReportReceiver() external view returns (address);

    /**
     * @notice Set the receiver contract address to be called when the report is pushed to Lido
     */
    function setBeaconReportReceiver(address _addr) external;

    /**
     * @notice Return the current reporting bitmap, representing oracles who have already pushed
     * their version of report during the expected epoch
     */
    function getCurrentOraclesReportStatus() external view returns (uint256);

    /**
     * @notice Return the current reporting array size
     */
    function getCurrentReportVariantsSize() external view returns (uint256);

    /**
     * @notice Return the current reporting array element with the given index
     */
    function getCurrentReportVariant(
        uint256 _index
    ) external view returns (uint64 beaconBalance, uint32 beaconValidators, uint16 count);

    /**
     * @notice Return epoch that can be reported by oracles
     */
    function getExpectedEpochId() external view returns (uint256);

    /**
     * @notice Return the current oracle member committee list
     */
    function getOracleMembers() external view returns (address[] memory);

    /**
     * @notice Return beacon specification data
     */
    function getBeaconSpec()
        external
        view
        returns (uint64 epochsPerFrame, uint64 slotsPerEpoch, uint64 secondsPerSlot, uint64 genesisTime);

    /**
     * Updates beacon specification data
     */
    function setBeaconSpec(
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime
    ) external;

    /**
     * Returns the epoch calculated from current timestamp
     */
    function getCurrentEpochId() external view returns (uint256);

    /**
     * @notice Return currently reportable epoch (the first epoch of the current frame) as well as
     * its start and end times in seconds
     */
    function getCurrentFrame()
        external
        view
        returns (uint256 frameEpochId, uint256 frameStartTime, uint256 frameEndTime);

    /**
     * @notice Return last completed epoch
     */
    function getLastCompletedEpochId() external view returns (uint256);

    /**
     * @notice Report beacon balance and its change during the last frame
     */
    function getLastCompletedReportDelta()
        external
        view
        returns (uint256 postTotalPooledEther, uint256 preTotalPooledEther, uint256 timeElapsed);

    /**
     * @notice Initialize the contract (version 3 for now) from scratch
     * @param _epochsPerFrame Number of epochs per frame
     * @param _slotsPerEpoch Number of slots per epoch
     * @param _secondsPerSlot Number of seconds per slot
     * @param _genesisTime Genesis time
     */
    function initialize(
        //        address _dawnpool,
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime
    ) external;

    /**
     * @notice Add `_member` to the oracle member committee list
     */
    function addOracleMember(address _member) external;

    /**
     * @notice Remove '_member` from the oracle member committee list
     */
    function removeOracleMember(address _member) external;

    /**
     * @notice Set the number of exactly the same reports needed to finalize the epoch to `_quorum`
     */
    function setQuorum(uint256 _quorum) external;

    //    function reportBeacon(uint256 _epochId, uint256 _beaconBalance, uint256 _beaconValidators, uint256 _rewardsVaultBalance, uint256 _exitedValidators,
    //        uint256 _burnedPEthAmount ,uint256 _lastRequestIdToBeFulfilled, uint256 _ethAmountToLock) external;
}
