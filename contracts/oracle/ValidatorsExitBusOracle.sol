// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import "../base/DawnBase.sol";
import "./DawnPoolOracle.sol";
import "./ReportUtils.sol";
import "../interface/IDepositNodeManager.sol";
import "../interface/IValidatorsExitBusOracle.sol";

contract ValidatorsExitBusOracle is IValidatorsExitBusOracle, DawnBase {
    constructor(IDawnStorageInterface dawnStorageAddress) DawnBase(dawnStorageAddress) {}

    using ReportUtils for uint256;

    /// @dev Storage slot: uint256 lastProcessingRefSlot
    bytes32 internal constant LAST_PROCESSING_REF_EPOCH_POSITION =
        keccak256("ValidatorsExitBusOracle.LAST_PROCESSING_REF_EPOCH_POSITION");

    bytes32 internal constant _QUORUM_POSITION = keccak256("ValidatorsExitBusOracle.QUORUM_POSITION");

    /// Epoch that we currently collect reports
    bytes32 internal constant _EXPECTED_EPOCH_ID_POSITION =
        keccak256("ValidatorsExitBusOracle.EXPECTED_EPOCH_ID_POSITION");

    /// The bitmask of the oracle members that pushed their reports
    bytes32 internal constant _REPORTS_BITMASK_POSITION = keccak256("ValidatorsExitBusOracle.REPORTS_BITMASK_POSITION");

    /// Storage for the actual beacon chain specification
    bytes32 internal constant _BEACON_SPEC_POSITION = keccak256("ValidatorsExitBusOracle.BEACON_SPEC_POSITION");

    error UnsupportedRequestsDataFormat(uint256 format);

    struct BeaconSpec {
        uint64 epochsPerFrame;
        uint64 slotsPerEpoch;
        uint64 secondsPerSlot;
        uint64 genesisTime;
    }

    //    /// Chain specification
    //    uint64 internal immutable SLOTS_PER_EPOCH;
    //    uint64 internal immutable SECONDS_PER_SLOT;
    //    uint64 internal immutable GENESIS_TIME;

    /// Maximum number of oracle committee members
    uint256 public constant MAX_MEMBERS = 256;

    uint256 internal constant MEMBER_NOT_FOUND = 2 ** 256 - 1;
    /// Contract structured storage
    address[] private members; /// slot 0: oracle committee members
    uint256[] private currentReportVariants; /// slot 1: reporting storage

    /// Data provider interface
    /// 包含了 Oracle 共识信息、请求数据格式和验证者退出请求数据等多方面的信息
    struct ReportData {
        // 表示报告计算所依据的参考时隙
        uint256 refEpoch;
        // 表示在此报告中相关联的验证器退出请求的总数
        uint256 requestsCount;

        // 表示验证器退出请求数据的格式。目前仅支持 DATA_FORMAT_LIST=1
        //        uint256 dataFormat;
    }

    //
    //    struct ConsensusReport {
    //        bytes32 hash;
    //        uint64 refSlot;
    //        uint64 processingDeadlineTime;
    //    }

    uint256 public constant DATA_FORMAT_LIST = 1;

    /**
     * @notice Return the DepositNodeManager contract address
     */
    function getDepositNodeManager() public view returns (IDepositNodeManager) {
        return IDepositNodeManager(_getContractAddress("DepositNodeManager"));
    }

    /// 提交报告数据，并进行一些必要的检查和处理操作。合约管理员可以根据需要调用此函数来处理提交的报告数据  whenResumed 则表示只有当合约恢复时才可以调用该函数 todo
    function submitReportData(ReportData calldata data) external {
        BeaconSpec memory beaconSpec = _getBeaconSpec();
        uint256 expectedEpoch = _getUint(_EXPECTED_EPOCH_ID_POSITION);
        //确保传入的_epochId大于等于预期的 epoch ID，以避免提交过时的验证报告
        require(data.refEpoch >= expectedEpoch, "EPOCH_IS_TOO_OLD");

        // if expected epoch has advanced, check that this is the first epoch of the current frame
        // and clear the last unsuccessful reporting todo 退出验证者多久上报一次
        if (data.refEpoch > expectedEpoch) {
            require(
                data.refEpoch == _getFrameFirstEpochId(_getCurrentEpochId(beaconSpec), beaconSpec),
                "UNEXPECTED_EPOCH"
            );
            //清除上一次未成功的验证报告并将预期的 epoch ID 更新为 _epochId。
            _clearReportingAndAdvanceTo(data.refEpoch);
        }

        // 获取调用者在 dawnpool 合约中的成员 ID, 以确保调用者是 dawnpool 合约的授权成员之一
        uint256 index = _getMemberId(msg.sender);
        require(index != MEMBER_NOT_FOUND, "MEMBER_NOT_FOUND");

        // 获取当前所有已提交验证报告的位表示，将其存储到变量 bitMask 中
        uint256 bitMask = _getUint(_REPORTS_BITMASK_POSITION);
        // 定义一个掩码变量 mask，将其设置为 1 左移 index 位，这样 mask 就表示了调用者可以使用的位，即第 index 位。
        uint256 mask = 1 << index;
        // 以确保调用者没有在当前轮中提交过验证报告
        require(bitMask & mask == 0, "ALREADY_SUBMITTED");
        // 验证通过了，则会将 bitMask 的第 index 位设置为 1, 以标记该调用者已经提交了验证报告
        _setUint(_REPORTS_BITMASK_POSITION, bitMask | mask);

        // 获取当前所需的最低验证报告数量 quorum
        uint256 quorum = getQuorum();
        uint256 i = 0;

        // iterate on all report variants we already have, limited by the oracle members maximum
        while (i < currentReportVariants.length) ++i;
        if (i < currentReportVariants.length) {
            // 判断该 variant 的计数器是否已达到要求的数量.达到，则会通过调用 _push() 更新 dawnpool 合约的 validator 列表
            if (currentReportVariants[i].getCount() + 1 >= quorum) {
                _handleConsensusReportData(data, beaconSpec);
            } else {
                // 增加对应 variant 的报告计数器
                ++currentReportVariants[i];
            }
        } else {
            // 只需要一个验证报告即可，则直接调用 _push()
            if (quorum == 1) {
                _handleConsensusReportData(data, beaconSpec);
            }
            //                else {
            //                currentReportVariants.push(report + 1);
            //            }
        }

        // 处理提交的报告数据
        //        _startProcessing();
        _setUint(LAST_PROCESSING_REF_EPOCH_POSITION, data.refEpoch);
    }

    function _handleConsensusReportData(ReportData calldata data, BeaconSpec memory _beaconSpec) internal {
        if (data.requestsCount == 0) {
            return;
        }

        IDepositNodeManager nodeManager = getDepositNodeManager();
        nodeManager.updateValidatorsExit(data.requestsCount);

        uint256 timestamp = _getTime();

        // 将验证器退出请求的相关信息转换成事件并派发到链上，以供其他程序查询和使用。
        emit ValidatorExitRequest(data.requestsCount, timestamp);
    }

    /**
     * @notice Return the number of exactly the same reports needed to finalize the epoch
     */
    function getQuorum() public view returns (uint256) {
        return _getUint(_QUORUM_POSITION);
    }

    /**
     *
     * @dev 获取当前的 oracles 报告状态
     */
    function getCurrentOraclesReportStatus() external view returns (uint256) {
        return _getUint(_REPORTS_BITMASK_POSITION);
    }

    function getChainConfig()
        external
        view
        returns (uint256 slotsPerEpoch, uint256 secondsPerSlot, uint256 genesisTime, uint256 epochsPerFrame)
    {
        BeaconSpec memory beaconSpec = _getBeaconSpec();
        return (beaconSpec.slotsPerEpoch, beaconSpec.secondsPerSlot, beaconSpec.genesisTime, beaconSpec.epochsPerFrame);
    }

    /**
     * @notice 返回 currentReportVariants 数组中指定索引位置的元素
     */
    function getCurrentReportVariant(
        uint256 _index
    ) external view returns (uint64 beaconBalance, uint32 beaconValidators, uint16 count) {
        return currentReportVariants[_index].decodeWithCount();
    }

    /**
     * @notice 获取当前 dawnpool 合约的所有 Oracle 成员地址。
     */
    function getOracleMembers() external view returns (address[] memory) {
        return members;
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
     * @notice 清除上一次未成功的验证报告并将预期的 epoch ID 更新为 _epochId。 todo 调用次数时间
     */
    function _clearReportingAndAdvanceTo(uint256 _epochId) internal {
        //        REPORTS_BITMASK_POSITION.setStorageUint256(0);
        _setUint(_REPORTS_BITMASK_POSITION, 0);
        _setUint(_EXPECTED_EPOCH_ID_POSITION, _epochId);
        delete currentReportVariants;
        emit ExpectedEpochIdUpdated(_epochId);
    }

    /**
     * @notice 更新 BeaconChain 规格信息
     * 权限控制 onlyGuardian todo
     */
    function setBeaconSpec(
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime
    ) external onlyGuardian {
        _setBeaconSpec(_epochsPerFrame, _slotsPerEpoch, _secondsPerSlot, _genesisTime);
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

        uint256 data = ((uint256(_epochsPerFrame) << 192) |
            (uint256(_slotsPerEpoch) << 128) |
            (uint256(_secondsPerSlot) << 64) |
            uint256(_genesisTime));
        //        BEACON_SPEC_POSITION.setStorageUint256(data);
        _setUint(_BEACON_SPEC_POSITION, data);
        emit BeaconSpecSet(_epochsPerFrame, _slotsPerEpoch, _secondsPerSlot, _genesisTime);
    }

    /**
     * @notice 获取当前报告变量的数量
     */
    function getCurrentReportVariantsSize() external view returns (uint256) {
        return currentReportVariants.length;
    }

    function decodeWithCount(
        uint256 value
    ) internal pure returns (uint64 beaconBalance, uint32 beaconValidators, uint16 count) {
        beaconBalance = uint64(value >> 48);
        beaconValidators = uint32(value >> 16);
        count = uint16(value);
    }

    /**
     * @notice 获取当前 EpochId
     */
    function getCurrentEpochId() external view returns (uint256) {
        BeaconSpec memory beaconSpec = _getBeaconSpec();
        return _getCurrentEpochId(beaconSpec);
    }

    /**
     * @notice 设置 dawnpool 合约中的最低投票数量，即 quorum 值
     * auth(MANAGE_QUORUM) todo
     */
    function setQuorum(uint256 _quorum) external onlyGuardian {
        require(0 != _quorum, "QUORUM_WONT_BE_MADE");

        uint256 oldQuorum = _getUint(_QUORUM_POSITION);
        _setUint(_QUORUM_POSITION, _quorum);
        emit QuorumChanged(_quorum);

        // 如果新的 quorum 值比旧值更小，即降低了 quorum 要求，则需要检查当前是否存在足够的提交验证报告的节点数，以便在达到 quorum 要求后触发新的验证操作
        if (oldQuorum > _quorum) {
            //获取当前存在的验证报告信息
            (bool isQuorum, uint256 report) = _getQuorumReport(_quorum);
            if (isQuorum) {
                (uint64 beaconBalance, uint32 beaconValidators) = report.decode();
                //触发新的验证操作，其参数包括预期的 epoch ID、当前贡献总量、验证节点数量和 Beacon chain 规范信息
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
     * @notice 取指定成员的 ID
     */
    function _getMemberId(address _member) internal view returns (uint256) {
        uint256 length = members.length;
        for (uint256 i = 0; i < length; ++i) {
            if (members[i] == _member) {
                return i;
            }
        }
        return MEMBER_NOT_FOUND;
    }

    /**
     * @notice 从合约中获取当前与指定 quorum 值对应的验证报告信息
     * 返回一个布尔值 isQuorum 表示是否满足 quorum 要求，一个整数 report 表示对应的验证报告信息
     */
    function _getQuorumReport(uint256 _quorum) internal view returns (bool isQuorum, uint256 report) {
        // 如果当前样本中只有一种报告，那么直接返回这个报告和它的出现次数
        if (currentReportVariants.length == 1) {
            return (currentReportVariants[0].getCount() >= _quorum, currentReportVariants[0]);
            // 如果当前样本为空，那么直接返回 false 和 0
        } else if (currentReportVariants.length == 0) {
            return (false, 0);
        }

        // 如果当前样本中存在多种报告，则需要选出其中出现次数最多的一种
        uint256 maxind = 0;
        uint256 repeat = 0;
        uint16 maxval = 0;
        uint16 cur = 0;
        // 记录当前出现次数最多的报告索引 maxind、其出现次数 maxval，并记录重复次数 repeat
        for (uint256 i = 0; i < currentReportVariants.length; ++i) {
            cur = currentReportVariants[i].getCount();
            //如果遍历到的报告次数大于等于 maxval，则更新最大值和对应的索引，
            if (cur >= maxval) {
                // 如果遍历到的报告次数等于 maxval，则增加 repeat 计数器
                if (cur == maxval) {
                    ++repeat;
                } else {
                    maxind = i;
                    maxval = cur;
                    repeat = 0;
                }
            }
        }
        // 将返回当前出现次数最多的报告和它的出现次数 maxval 是否超过了 _quorum。如果超过，则返回 true 和这个报告，否则返回 false 和 0。
        return (maxval >= _quorum && repeat == 0, currentReportVariants[maxind]);
    }

    /**
     *  通过调用 _getTime() 函数来获取当前区块时间戳，并将其减去 Genesis 时间,除以每个 Epoch 的总时长（即 Slot 时长乘以 Slot 数目）
     * @notice 获取当前时刻所处的 Epoch ID
     */
    function _getCurrentEpochId(BeaconSpec memory _beaconSpec) internal view returns (uint256) {
        return (_getTime() - _beaconSpec.genesisTime) / (_beaconSpec.slotsPerEpoch * _beaconSpec.secondsPerSlot);
    }

    function initialize(
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime,
        uint256 _lastProcessingRefSlot
    ) external {
        _setUint(LAST_PROCESSING_REF_EPOCH_POSITION, _lastProcessingRefSlot);

        _setBeaconSpec(_epochsPerFrame, _slotsPerEpoch, _secondsPerSlot, _genesisTime);

        //Quorum 值用于对 dawnpool DAO 委员会成员进行投票,将其初始化为 1，表示只需要一个委员会成员的投票即可生效
        _setUint(_QUORUM_POSITION, 1);
        emit QuorumChanged(1);
        // set expected epoch to the first epoch for the next frame
        BeaconSpec memory beaconSpec = _getBeaconSpec();
        // Epoch 所属的 Frame 的第一个 Epoch ID
        uint256 expectedEpoch = _getFrameFirstEpochId(0, beaconSpec) + beaconSpec.epochsPerFrame;
        _setUint(_EXPECTED_EPOCH_ID_POSITION, expectedEpoch);
        emit ExpectedEpochIdUpdated(expectedEpoch);
    }

    /**
     * @notice 获取当前区块时间戳
     */
    function _getTime() internal view returns (uint256) {
        return block.timestamp; // solhint-disable-line not-rely-on-time
    }

    /// @notice Returns the last reference slot for which processing of the report was started.
    ///
    function getLastProcessingRefSlot() external view returns (uint256) {
        return _getUint(LAST_PROCESSING_REF_EPOCH_POSITION);
    }

    function getLastProcessingRefEpoch() external view returns (uint256) {
        return _getUint(LAST_PROCESSING_REF_EPOCH_POSITION);
    }

    /**
     *  首先通过 _epochId 除以 _beaconSpec.epochsPerFrame 来计算出该 Epoch 所处的 Frame 编号，然后将其乘以 _beaconSpec.epochsPerFrame，即可得到该 Frame 的第一个 Epoch ID
     * @notice Epoch 所属的 Frame 的第一个 Epoch ID
     */
    function _getFrameFirstEpochId(uint256 _epochId, BeaconSpec memory _beaconSpec) internal pure returns (uint256) {
        return (_epochId / _beaconSpec.epochsPerFrame) * _beaconSpec.epochsPerFrame;
    }

    /**
     * 向 dawnpool 合约中添加新的 Oracle 成员
     * todo
     */
    function addOracleMember(address _member) external onlyGuardian {
        require(address(0) != _member, "BAD_ARGUMENT");
        require(MEMBER_NOT_FOUND == _getMemberId(_member), "MEMBER_EXISTS");
        require(members.length < MAX_MEMBERS, "TOO_MANY_MEMBERS");

        members.push(_member);

        emit MemberAdded(_member);
    }
}
