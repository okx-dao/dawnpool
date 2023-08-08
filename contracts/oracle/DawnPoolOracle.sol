// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interface/IDawnPoolOracle.sol";
import "../interface/IHashConsensus.sol";
import "../interface/IDawnDeposit.sol";
import "../base/DawnBase.sol";
import "./ReportUtils.sol";

contract DawnPoolOracle is IDawnPoolOracle, DawnBase, ReentrancyGuard {
    constructor(IDawnStorageInterface dawnStorageAddress) DawnBase(dawnStorageAddress) {}

    using ReportUtils for uint256;

    struct BeaconSpec {
        uint64 epochsPerFrame;
        uint64 slotsPerEpoch;
        uint64 secondsPerSlot;
        uint64 genesisTime;
    }

    struct ReportData {
        uint256 epochId;
        uint256 beaconBalance;
        uint256 beaconValidators;
        uint256 rewardsVaultBalance;
        uint256 exitedValidators;
        uint256 burnedPEthAmount;
        uint256 lastRequestIdToBeFulfilled;
        uint256 ethAmountToLock;
    }

    /// @dev Storage Epoch: uint256 lastProcessingRefEpoch
    bytes32 internal constant _LAST_PROCESSING_REF_EPOCH_POSITION =
    keccak256("DawnPoolOracle._LAST_PROCESSING_REF_EPOCH_POSITION");

    /// Maximum number of oracle committee _members
    uint256 public constant MAX_MEMBERS = 256;

    uint256 internal constant _MEMBER_NOT_FOUND = 2 ** 256 - 1;

    /// Number of exactly the same reports needed to finalize the epoch

    bytes32 internal constant _QUORUM_POSITION = keccak256("DawnPoolOracle.QUORUM_POSITION");

    /// Address of the dawnpool contract
    //    bytes32 internal constant _DAWNPOOL_POSITION = keccak256("DawnPoolOracle.DAWNPOOL_POSITION");

    /// Storage for the actual beacon chain specification
    bytes32 internal constant _BEACON_SPEC_POSITION = keccak256("DawnPoolOracle.BEACON_SPEC_POSITION");

    /// Epoch that we currently collect reports
    bytes32 internal constant _EXPECTED_EPOCH_ID_POSITION = keccak256("DawnPoolOracle.EXPECTED_EPOCH_ID_POSITION");

    /// The bitmask of the oracle _members that pushed their reports
    bytes32 internal constant _REPORTS_BITMASK_POSITION = keccak256("DawnPoolOracle.REPORTS_BITMASK_POSITION");

    /// Historic data about 2 last completed reports and their times
    bytes32 internal constant _POST_COMPLETED_TOTAL_POOLED_ETHER_POSITION =
        keccak256("DawnPoolOracle.POST_COMPLETED_TOTAL_POOLED_ETHER_POSITION");

    bytes32 internal constant _PRE_COMPLETED_TOTAL_POOLED_ETHER_POSITION =
        keccak256("DawnPoolOracle.PRE_COMPLETED_TOTAL_POOLED_ETHER_POSITION");

    bytes32 internal constant _LAST_COMPLETED_EPOCH_ID_POSITION =
        keccak256("DawnPoolOracle.LAST_COMPLETED_EPOCH_ID_POSITION");

    bytes32 internal constant _TIME_ELAPSED_POSITION = keccak256("DawnPoolOracle.TIME_ELAPSED_POSITION");

    /// Receiver address to be called when the report is pushed to dawnpool
    bytes32 internal constant _BEACON_REPORT_RECEIVER_POSITION =
        keccak256("DawnPoolOracle.BEACON_REPORT_RECEIVER_POSITION");

    uint256[] private _currentReportVariants; /// slot 1: reporting storage

    /**
     * @notice Return the DawnPool contract address
     */
    function getDawnDeposit() public view returns (IDawnDeposit) {
        return IDawnDeposit(_getContractAddress("DawnDeposit"));
    }

    /**
     * @notice 返回 Beacon 报告接收者的地址，即在 Beacon 链上提出提案所需提交的报告的接收地址
     */
    function getBeaconReportReceiver() external view returns (address) {
        return _getAddress(_BEACON_REPORT_RECEIVER_POSITION);
    }

    /**
     * @notice Set the receiver contract address to `addr` to be called when the report is pushed
     * @dev Specify 0 to disable this functionality
     *  添加权限控制  onlyGuardian
     */
    function setBeaconReportReceiver(address addr) external onlyGuardian {
        if (addr != address(0)) {
            // 对 addr 进行支持性验证
        }
        //使其他用户可以监听该事件并获取新值的更新情况
        emit BeaconReportReceiverSet(addr);
        _setAddress(_BEACON_REPORT_RECEIVER_POSITION, addr);
    }

    /**
     *
     * @dev 获取当前的 oracles 报告状态
     */
    function getCurrentOraclesReportStatus() external view returns (uint256) {
        return _getUint(_REPORTS_BITMASK_POSITION);
    }

    /**
     * @notice 获取当前报告变量的数量
     */
    function getCurrentReportVariantsSize() external view returns (uint256) {
        return _currentReportVariants.length;
    }

    /**
     * @notice 获取当前期望的 epoch ID 值
     */
    function getExpectedEpochId() external view returns (uint256) {
        return _getUint(_EXPECTED_EPOCH_ID_POSITION);
    }

    /**
     * @notice  获取 dawnpool 合约所使用的 BeaconChain 规格信息
     */
    function getBeaconSpec()
        external
        view
        returns (uint64 epochsPerFrame, uint64 slotsPerEpoch, uint64 secondsPerSlot, uint64 genesisTime)
    {
        BeaconSpec memory beaconSpec = _getBeaconSpec();
        return (beaconSpec.epochsPerFrame, beaconSpec.slotsPerEpoch, beaconSpec.secondsPerSlot, beaconSpec.genesisTime);
    }

    /**
     * @notice 更新 BeaconChain 规格信息
     * 权限控制 onlyGuardian todo
     */
    function setBeaconSpec(
        uint64 epochsPerFrame,
        uint64 slotsPerEpoch,
        uint64 secondsPerSlot,
        uint64 genesisTime
    ) external onlyGuardian {
        _setBeaconSpec(epochsPerFrame, slotsPerEpoch, secondsPerSlot, genesisTime);
    }

    /**
     * @notice 获取当前 EpochId
     */
    function getCurrentEpochId() external view returns (uint256) {
        BeaconSpec memory beaconSpec = _getBeaconSpec();
        return _getCurrentEpochId(beaconSpec);
    }

    /**
     *
     * 返回当前 dawnpool 合约所处的 BeaconChain 帧信息
     */
    function getCurrentFrame()
        external
        view
        returns (uint256 frameEpochId, uint256 frameStartTime, uint256 frameEndTime)
    {
        BeaconSpec memory beaconSpec = _getBeaconSpec();
        uint64 genesisTime = beaconSpec.genesisTime;
        uint64 secondsPerEpoch = beaconSpec.secondsPerSlot * beaconSpec.slotsPerEpoch;

        frameEpochId = _getFrameFirstEpochId(_getCurrentEpochId(beaconSpec), beaconSpec);
        frameStartTime = frameEpochId * secondsPerEpoch + genesisTime;
        frameEndTime = (frameEpochId + beaconSpec.epochsPerFrame) * secondsPerEpoch + genesisTime - 1;
    }

    /**
     * @notice 获取 dawnpool 合约中存储的最后完成的 Epoch ID
     */
    function getLastCompletedEpochId() external view returns (uint256) {
        return _getUint(_LAST_COMPLETED_EPOCH_ID_POSITION);
    }

    /**
     * @notice 获取 dawnpool 合约中存储的最后一次完成报告的相关信息
     */
    function getLastCompletedReportDelta()
        external
        view
        returns (uint256 postTotalPooledEther, uint256 preTotalPooledEther, uint256 timeElapsed)
    {
        //完成报告后合约中存储的总质押 ETH 数量
        postTotalPooledEther = _getUint(_POST_COMPLETED_TOTAL_POOLED_ETHER_POSITION);
        //完成报告前合约中存储的总质押 ETH 数量
        preTotalPooledEther = _getUint(_PRE_COMPLETED_TOTAL_POOLED_ETHER_POSITION);
        //完成报告前后经过的时间
        timeElapsed = _getUint(_TIME_ELAPSED_POSITION);
    }

    /**
     * @notice Initialize the contract (version 3 for now) from scratch
     * @param epochsPerFrame Number of epochs per frame
     * @param slotsPerEpoch Number of slots per epoch
     * @param secondsPerSlot Number of seconds per slot
     * @param genesisTime Genesis time
     * onlyGuardian
     */
    function initialize(
        uint64 epochsPerFrame,
        uint64 slotsPerEpoch,
        uint64 secondsPerSlot,
        uint64 genesisTime,
        uint64 lastProcessingRefSlot
    ) external onlyGuardian {

        _setUint(_LAST_PROCESSING_REF_EPOCH_POSITION, lastProcessingRefSlot);
        // We consider storage state right after deployment (no initialize() called yet) as version 0

        _setBeaconSpec(epochsPerFrame, slotsPerEpoch, secondsPerSlot, genesisTime);

        // set expected epoch to the first epoch for the next frame
        BeaconSpec memory beaconSpec = _getBeaconSpec();
        // Epoch 所属的 Frame 的第一个 Epoch ID
        uint256 expectedEpoch = _getFrameFirstEpochId(0, beaconSpec) + beaconSpec.epochsPerFrame;
        _setUint(_EXPECTED_EPOCH_ID_POSITION, expectedEpoch);
        emit ExpectedEpochIdUpdated(expectedEpoch);


    }

    function getLastProcessingRefEpoch() external view returns (uint256) {
        return _getUint(_LAST_PROCESSING_REF_EPOCH_POSITION);
    }

    /**
     * @notice Accept oracle committee member reports from the ETH 2.0 side
     * @param data ReportData   兼容进程，方法名需改为 submitReportData
     */
    function submitReportData(ReportData calldata data) external nonReentrant{

        BeaconSpec memory beaconSpec = _getBeaconSpec();
        uint256 expectedEpoch = _getUint(_EXPECTED_EPOCH_ID_POSITION);
        //确保传入的_epochId大于等于预期的 epoch ID，以避免提交过时的验证报告
        require(data.epochId >= expectedEpoch, "EPOCH_IS_TOO_OLD");

        // if expected epoch has advanced, check that this is the first epoch of the current frame
        // and clear the last unsuccessful reporting
        if (data.epochId > expectedEpoch) {
        require(
                data.epochId == _getFrameFirstEpochId(_getCurrentEpochId(beaconSpec), beaconSpec),
                "UNEXPECTED_EPOCH"
            );
            //清将预期的 epoch ID 更新为 _epochId。
            _clearReportingAndAdvanceTo(data.epochId);
        }

        emit BeaconReported(
            data.epochId,
            data.beaconBalance,
            data.beaconValidators,
            data.rewardsVaultBalance,
            data.exitedValidators,
            data.burnedPEthAmount,
            data.lastRequestIdToBeFulfilled,
            data.ethAmountToLock,
            msg.sender
        );


        // 获取调用者在 dawnpool 合约中的成员 ID, 以确保调用者是 dawnpool 合约的授权成员之一
        uint256 index = IHashConsensus(_getContractAddressUnsafe("HashConsensus"))
        .getMemberId(msg.sender);
//        uint256 index = getMemberId(msg.sender);
        require(index != _MEMBER_NOT_FOUND, "MEMBER_NOT_FOUND");
        // 获取当前所有已提交验证报告的位表示，将其存储到变量 bitMask 中
        uint256 bitMask = _getUint(_REPORTS_BITMASK_POSITION);
        // 定义一个掩码变量 mask，将其设置为 1 左移 index 位，这样 mask 就表示了调用者可以使用的位，即第 index 位。
        uint256 mask = 1 << index;
        // 以确保调用者没有在当前轮中提交过验证报告
        require(bitMask & mask == 0, "ALREADY_SUBMITTED");
        // 验证通过了，则会将 bitMask 的第 index 位设置为 1, 以标记该调用者已经提交了验证报告
        _setUint(_REPORTS_BITMASK_POSITION, bitMask | mask);

        // 将 _beaconBalance 和 _beaconValidators 编码为一个 uint256 类型的整数
        uint256 report = (uint256(data.beaconBalance) << 48) | (uint256(data.beaconValidators) << 16);
        // 获取当前所需的最低验证报告数量 quorum
        uint256 quorum = IHashConsensus(_getContractAddressUnsafe("HashConsensus"))
        .getQuorum();
//        uint256 quorum = getQuorum();
        uint256 i = 0;

        // iterate on all report variants we already have, limited by the oracle _members maximum
        while (i < _currentReportVariants.length && _currentReportVariants[i].isDifferent(report)) ++i;
        if (i < _currentReportVariants.length) {
            // 判断该 variant 的计数器是否已达到要求的数量.达到，则会通过调用 _push() 更新 dawnpool 合约的 validator 列表
            if (_currentReportVariants[i].getCount() + 1 >= quorum) {
                _push(data, beaconSpec);
            } else {
                // 增加对应 variant 的报告计数器
                ++_currentReportVariants[i];
            }
        } else {
            // 只需要一个验证报告即可，则直接调用 _push()
            if (quorum == 1) {
                _push(data, beaconSpec);
            } else {
                //创建一个新的 variant 并将其添加到 _currentReportVariants 数组中。
                _currentReportVariants.push(report + 1);
            }
        }

    }

    /**
     * @notice Return beacon specification data
     */
    function _getBeaconSpec() internal view returns (BeaconSpec memory beaconSpec) {
        //        uint256 data = BEACON_SPEC_POSITION.getStorageUint256();
        uint256 data = _getUint(_BEACON_SPEC_POSITION);
        beaconSpec.epochsPerFrame = uint64(data >> 192);
        beaconSpec.slotsPerEpoch = uint64(data >> 128);
        beaconSpec.secondsPerSlot = uint64(data >> 64);
        beaconSpec.genesisTime = uint64(data);
        return beaconSpec;
    }


    /**
     * @notice Set beacon specification data  定义当前区块链上的信标链规范数据
     */
    function _setBeaconSpec(
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime
    ) internal {
        require(_epochsPerFrame > 0, "BAD_EPOCHS_PER_FRAME");
        require(_slotsPerEpoch > 0, "BAD_SLOTS_PER_EPOCH");
        require(_secondsPerSlot > 0, "BAD_SECONDS_PER_SLOT");
        require(_genesisTime > 0, "BAD_GENESIS_TIME");

        emit BeaconSpecSet(_epochsPerFrame, _slotsPerEpoch, _secondsPerSlot, _genesisTime);
        uint256 data = ((uint256(_epochsPerFrame) << 192) |
            (uint256(_slotsPerEpoch) << 128) |
            (uint256(_secondsPerSlot) << 64) |
            uint256(_genesisTime));
        _setUint(_BEACON_SPEC_POSITION, data);
    }

    /**
     * @notice Push the given report and performs accompanying accounting
     * @param data ReportData
     * @param _beaconSpec current beacon specification data
     */
    function _push(ReportData calldata data, BeaconSpec memory _beaconSpec) internal {
        // 发布为一个 Completed 事件，表示前一个 Epoch 已完成
        emit Completed(
            data.epochId,
            data.beaconValidators,
            data.beaconBalance,
            data.rewardsVaultBalance,
            data.exitedValidators,
            data.burnedPEthAmount,
            data.lastRequestIdToBeFulfilled,
            data.ethAmountToLock
        );

        // 清除上一次未成功的验证报告并将预期的 epoch ID 更新为 _epochId。
        _clearReportingAndAdvanceTo(data.epochId + _beaconSpec.epochsPerFrame);

        // report to the dawnPool and collect stats
        IDawnDeposit dawnPool = getDawnDeposit();

        dawnPool.handleOracleReport(
            data.epochId,
            data.beaconValidators,
            data.beaconBalance,
            data.rewardsVaultBalance,
            data.exitedValidators,
            data.burnedPEthAmount,
            data.lastRequestIdToBeFulfilled,
            data.ethAmountToLock
        );
        _setUint(_LAST_PROCESSING_REF_EPOCH_POSITION, data.epochId);
    }

    /**
     * @notice 清除上一次未成功的验证报告并将预期的 epoch ID 更新为 _epochId。
     */
    function _clearReportingAndAdvanceTo(uint256 _epochId) internal {
        _setUint(_REPORTS_BITMASK_POSITION, 0);
        _setUint(_EXPECTED_EPOCH_ID_POSITION, _epochId);
        delete _currentReportVariants;
        emit ExpectedEpochIdUpdated(_epochId);
    }

    /**
     *  通过调用 _getTime() 函数来获取当前区块时间戳，并将其减去 Genesis 时间,除以每个 Epoch 的总时长（即 Slot 时长乘以 Slot 数目）
     * @notice 获取当前时刻所处的 Epoch ID
     */
    function _getCurrentEpochId(BeaconSpec memory _beaconSpec) internal view returns (uint256) {
        return (_getTime() - _beaconSpec.genesisTime) / (_beaconSpec.slotsPerEpoch * _beaconSpec.secondsPerSlot);
    }

    /**
     *  首先通过 _epochId 除以 _beaconSpec.epochsPerFrame 来计算出该 Epoch 所处的 Frame 编号，然后将其乘以 _beaconSpec.epochsPerFrame，即可得到该 Frame 的第一个 Epoch ID
     *  todo 取当前Frame的第一帧 忽略 slither 的 performs a multiplication on the result of a division提醒
     */
    function _getFrameFirstEpochId(uint256 _epochId, BeaconSpec memory _beaconSpec) internal pure returns (uint256) {
        return (_epochId / _beaconSpec.epochsPerFrame) * _beaconSpec.epochsPerFrame;
    }

    function getFrameFirstEpochId() external view returns (uint256) {
        BeaconSpec memory beaconSpec = _getBeaconSpec();
        return _getFrameFirstEpochId(_getCurrentEpochId(beaconSpec), beaconSpec);
    }

    /**
     * @notice 获取当前区块时间戳
     */
    function _getTime() internal view returns (uint256) {
        return block.timestamp; // solhint-disable-line not-rely-on-time
    }
}
