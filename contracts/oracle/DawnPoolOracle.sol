// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDawnPoolOracle.sol";
import "../interface/IDawnDeposit.sol";
import "../base/DawnBase.sol";
import "./ReportUtils.sol";


contract DawnPoolOracle is IDawnPoolOracle, DawnBase {
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

    /// ACL
    bytes32 internal constant _MANAGE_QUORUM = keccak256("DawnPoolOracle.MANAGE_QUORUM");


    /// Maximum number of oracle committee members
    uint256 public constant MAX_MEMBERS = 256;

    /// Eth1 denomination is 18 digits, while Eth2 has 9 digits. Because we work with Eth2
    /// balances and to support old interfaces expecting eth1 format, we multiply by this
    /// coefficient.
    uint128 internal constant DENOMINATION_OFFSET = 1e9;

    uint256 internal constant MEMBER_NOT_FOUND = 2**256 - 1;

    /// Number of exactly the same reports needed to finalize the epoch

    bytes32 internal constant _QUORUM_POSITION = keccak256("DawnPoolOracle.QUORUM_POSITION");

    /// Address of the dawnpool contract
//    bytes32 internal constant _DAWNPOOL_POSITION = keccak256("DawnPoolOracle.DAWNPOOL_POSITION");


    /// Storage for the actual beacon chain specification
    bytes32 internal constant _BEACON_SPEC_POSITION = keccak256("DawnPoolOracle.BEACON_SPEC_POSITION");

    /// Version of the initialized contract data
    /// NB: Contract versioning starts from 1.
    /// The version stored in CONTRACT_VERSION_POSITION equals to
    /// - 0 right after deployment when no initializer is invoked yet
    /// - N after calling initialize() during deployment from scratch, where N is the current contract version
    /// - N after upgrading contract from the previous version (after calling finalize_vN())
    bytes32 internal constant _CONTRACT_VERSION_POSITION = keccak256("DawnPoolOracle.CONTRACT_VERSION_POSITION");

    /// Epoch that we currently collect reports
    bytes32 internal constant _EXPECTED_EPOCH_ID_POSITION = keccak256("DawnPoolOracle.EXPECTED_EPOCH_ID_POSITION");

    /// The bitmask of the oracle members that pushed their reports
    bytes32 internal constant _REPORTS_BITMASK_POSITION = keccak256("DawnPoolOracle.REPORTS_BITMASK_POSITION");

    /// Historic data about 2 last completed reports and their times
    bytes32 internal constant _POST_COMPLETED_TOTAL_POOLED_ETHER_POSITION = keccak256("DawnPoolOracle.POST_COMPLETED_TOTAL_POOLED_ETHER_POSITION");

    bytes32 internal constant _PRE_COMPLETED_TOTAL_POOLED_ETHER_POSITION = keccak256("DawnPoolOracle.PRE_COMPLETED_TOTAL_POOLED_ETHER_POSITION");

    bytes32 internal constant _LAST_COMPLETED_EPOCH_ID_POSITION = keccak256("DawnPoolOracle.LAST_COMPLETED_EPOCH_ID_POSITION");

    bytes32 internal constant _TIME_ELAPSED_POSITION = keccak256("DawnPoolOracle.TIME_ELAPSED_POSITION");

    /// Receiver address to be called when the report is pushed to dawnpool
    bytes32 internal constant _BEACON_REPORT_RECEIVER_POSITION = keccak256("DawnPoolOracle.BEACON_REPORT_RECEIVER_POSITION");

    /// Contract structured storage
    address[] private members;                /// slot 0: oracle committee members
    uint256[] private currentReportVariants;  /// slot 1: reporting storage

    /**
 * @notice Return the DawnPool contract address
     */
    function getDawnDeposit() public view returns (IDawnDeposit) {

        return IDawnDeposit(_getContractAddress("DawnDeposit"));
    }


    /**
     * @notice Return the number of exactly the same reports needed to finalize the epoch
     */
    function getQuorum() public view returns (uint256) {
        return _getUint(_QUORUM_POSITION);
    }


    /**
     * @notice 返回 Beacon 报告接收者的地址，即在 Beacon 链上提出提案所需提交的报告的接收地址
     */
    function getBeaconReportReceiver() external view returns (address) {
        return _getAddress(_BEACON_REPORT_RECEIVER_POSITION);
    }

    /**
     * @notice Set the receiver contract address to `_addr` to be called when the report is pushed
     * @dev Specify 0 to disable this functionality
     *  添加权限控制  onlyGuardian todo
     */
    function setBeaconReportReceiver(address _addr) external onlyGuardian {
        if(_addr != address(0)) {
            // 对 _addr 进行支持性验证 todo
        }

        _setAddress(_BEACON_REPORT_RECEIVER_POSITION, _addr);
        //使其他用户可以监听该事件并获取新值的更新情况
        emit BeaconReportReceiverSet(_addr);
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
        return currentReportVariants.length;
    }

    /**
     * @notice 返回 currentReportVariants 数组中指定索引位置的元素
     */
    function getCurrentReportVariant(uint256 _index)
    external
    view
    returns (
        uint64 beaconBalance,
        uint32 beaconValidators,
        uint16 count
    )
    {
        return currentReportVariants[_index].decodeWithCount();
    }

    /**
     * @notice 获取当前期望的 epoch ID 值
     */
    function getExpectedEpochId() external view returns (uint256) {
        return _getUint(_EXPECTED_EPOCH_ID_POSITION);
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
    returns (
        uint64 epochsPerFrame,
        uint64 slotsPerEpoch,
        uint64 secondsPerSlot,
        uint64 genesisTime
    )
    {
        BeaconSpec memory beaconSpec = _getBeaconSpec();
        return (
        beaconSpec.epochsPerFrame,
        beaconSpec.slotsPerEpoch,
        beaconSpec.secondsPerSlot,
        beaconSpec.genesisTime
        );
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
    )
    external onlyGuardian

    {
        _setBeaconSpec(
            _epochsPerFrame,
            _slotsPerEpoch,
            _secondsPerSlot,
            _genesisTime
        );
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
    returns (
        uint256 frameEpochId,
        uint256 frameStartTime,
        uint256 frameEndTime
    )
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
    returns (
        uint256 postTotalPooledEther,
        uint256 preTotalPooledEther,
        uint256 timeElapsed
    )
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
     * @dev For details see https://github.com/lidofinance/lido-improvement-proposals/blob/develop/LIPS/lip-10.md
     * @param _epochsPerFrame Number of epochs per frame
     * @param _slotsPerEpoch Number of slots per epoch
     * @param _secondsPerSlot Number of seconds per slot
     * @param _genesisTime Genesis time
     * onlyGuardian todo
     */
    function initialize(
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime
    )
    external onlyGuardian
    {
        assert(1 == ((1 << (MAX_MEMBERS - 1)) >> (MAX_MEMBERS - 1)));  // static assert

        // We consider storage state right after deployment (no initialize() called yet) as version 0

        // 在初始化版本为 0 时（即合约刚部署时），要求状态变量 CONTRACT_VERSION_POSITION 的值必须为 0，以保证该合约从初始状态开始。
        require(_getUint(_CONTRACT_VERSION_POSITION) == 0, "BASE_VERSION_MUST_BE_ZERO");

        _setBeaconSpec(
            _epochsPerFrame,
            _slotsPerEpoch,
            _secondsPerSlot,
            _genesisTime
        );

        // dawnpool 智能合约的地址 todo
//        _setAddress(_DAWNPOOL_POSITION,_dawnpool);


        //Quorum 值用于对 dawnpool DAO 委员会成员进行投票,将其初始化为 1，表示只需要一个委员会成员的投票即可生效
        _setUint(_QUORUM_POSITION, 1);
        emit QuorumChanged(1);

        // set expected epoch to the first epoch for the next frame
        BeaconSpec memory beaconSpec = _getBeaconSpec();
        // Epoch 所属的 Frame 的第一个 Epoch ID
        uint256 expectedEpoch = _getFrameFirstEpochId(0, beaconSpec) + beaconSpec.epochsPerFrame;
        _setUint(_EXPECTED_EPOCH_ID_POSITION,expectedEpoch);
        emit ExpectedEpochIdUpdated(expectedEpoch);


//        initialized();
    }



    /**
     * 向 dawnpool 合约中添加新的 Oracle 成员
     * todo
     */
    function addOracleMember(address _member) external onlyGuardian{
        require(address(0) != _member, "BAD_ARGUMENT");
        require(MEMBER_NOT_FOUND == _getMemberId(_member), "MEMBER_EXISTS");
        require(members.length < MAX_MEMBERS, "TOO_MANY_MEMBERS");

        members.push(_member);

        emit MemberAdded(_member);
    }

    /**
     * 向 dawnpool 合约中删除 Oracle 成员
     *  权限控制onlyGuardian todo
     */
    function removeOracleMember(address _member) external onlyGuardian {
        uint256 index = _getMemberId(_member);
        require(index != MEMBER_NOT_FOUND, "MEMBER_NOT_FOUND");
        uint256 last = members.length - 1;
        if (index != last) members[index] = members[last];
        members[index] = members[members.length - 1];
//        members.length--;
        emit MemberRemoved(_member);

        // 该函数在移除 Oracle 成员之后，还需要将与该成员相关的历史验证信息清除 (将存储在合约中的该 Oracle 成员所提交的最后一次验证报告的掩码值设为 0)
        _setUint(_REPORTS_BITMASK_POSITION, 0);
        //通过 delete currentReportVariants 语句从合约中删除该成员所提交的当前验证报告信息
        delete currentReportVariants;
    }

    /**
     * @notice 设置 dawnpool 合约中的最低投票数量，即 quorum 值
     * auth(MANAGE_QUORUM) todo
     */
    function setQuorum(uint256 _quorum) external  onlyGuardian{
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
     * @notice Accept oracle committee member reports from the ETH 2.0 side
     * @param data ReportData
     */
    function reportBeacon(ReportData calldata data) external {
        BeaconSpec memory beaconSpec = _getBeaconSpec();
        uint256 expectedEpoch = _getUint(_EXPECTED_EPOCH_ID_POSITION);
        //确保传入的_epochId大于等于预期的 epoch ID，以避免提交过时的验证报告
        require(data.epochId >= expectedEpoch, "EPOCH_IS_TOO_OLD");

        // if expected epoch has advanced, check that this is the first epoch of the current frame
        // and clear the last unsuccessful reporting
        if (data.epochId > expectedEpoch) {
            require(data.epochId == _getFrameFirstEpochId(_getCurrentEpochId(beaconSpec), beaconSpec), "UNEXPECTED_EPOCH");
            //清除上一次未成功的验证报告并将预期的 epoch ID 更新为 _epochId。
            _clearReportingAndAdvanceTo(data.epochId);
        }

        emit BeaconReported(data.epochId, data.beaconBalance, data.beaconValidators, data.rewardsVaultBalance,
            data.exitedValidators, data.burnedPEthAmount, data.lastRequestIdToBeFulfilled, data.ethAmountToLock, msg.sender);

        // 获取调用者在 dawnpool 合约中的成员 ID, 以确保调用者是 dawnpool 合约的授权成员之一 todo 二期再做
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

        // 将 _beaconBalance 和 _beaconValidators 编码为一个 uint256 类型的整数
        uint256 report = uint256(data.beaconBalance) << 48 | uint256(data.beaconValidators) << 16;
        // 获取当前所需的最低验证报告数量 quorum
        uint256 quorum = getQuorum();
        uint256 i = 0;

        // iterate on all report variants we already have, limited by the oracle members maximum
        while (i < currentReportVariants.length && currentReportVariants[i].isDifferent(report)) ++i;
        if (i < currentReportVariants.length) {
            // 判断该 variant 的计数器是否已达到要求的数量.达到，则会通过调用 _push() 更新 dawnpool 合约的 validator 列表
            if (currentReportVariants[i].getCount() + 1 >= quorum) {
                _push(data, beaconSpec);
            } else {
                // 增加对应 variant 的报告计数器
                ++currentReportVariants[i];
            }
        } else {
            // 只需要一个验证报告即可，则直接调用 _push()
            if (quorum == 1) {
                _push(data, beaconSpec);
            } else {
                //创建一个新的 variant 并将其添加到 currentReportVariants 数组中。
                currentReportVariants.push(report + 1);
            }
        }
    }

    /**
     * @notice Return beacon specification data
     */
    function _getBeaconSpec()
    internal
    view
    returns (BeaconSpec memory beaconSpec)
    {
//        uint256 data = BEACON_SPEC_POSITION.getStorageUint256();
        uint256 data = _getUint(_BEACON_SPEC_POSITION);
        beaconSpec.epochsPerFrame = uint64(data >> 192);
        beaconSpec.slotsPerEpoch = uint64(data >> 128);
        beaconSpec.secondsPerSlot = uint64(data >> 64);
        beaconSpec.genesisTime = uint64(data);
        return beaconSpec;
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
     * @notice Set beacon specification data  定义当前区块链上的信标链规范数据
     */
    function _setBeaconSpec(
        uint64 _epochsPerFrame,
        uint64 _slotsPerEpoch,
        uint64 _secondsPerSlot,
        uint64 _genesisTime
    )
    internal
    {
        require(_epochsPerFrame > 0, "BAD_EPOCHS_PER_FRAME");
        require(_slotsPerEpoch > 0, "BAD_SLOTS_PER_EPOCH");
        require(_secondsPerSlot > 0, "BAD_SECONDS_PER_SLOT");
        require(_genesisTime > 0, "BAD_GENESIS_TIME");

        uint256 data = (
        uint256(_epochsPerFrame) << 192 |
        uint256(_slotsPerEpoch) << 128 |
        uint256(_secondsPerSlot) << 64 |
        uint256(_genesisTime)
        );
//        BEACON_SPEC_POSITION.setStorageUint256(data);
        _setUint(_BEACON_SPEC_POSITION,data);
        emit BeaconSpecSet(
            _epochsPerFrame,
            _slotsPerEpoch,
            _secondsPerSlot,
            _genesisTime);
    }

    /**
     * @notice Push the given report and performs accompanying accounting
     * @param data ReportData
     * @param _beaconSpec current beacon specification data
     */
    function _push(
        ReportData calldata data,
        BeaconSpec memory _beaconSpec
    )
    internal
    {
        // 发布为一个 Completed 事件，表示前一个 Epoch 已完成
        emit Completed(data.epochId, data.beaconValidators, data.beaconBalance, data.rewardsVaultBalance, data.exitedValidators,
            data.burnedPEthAmount, data.lastRequestIdToBeFulfilled, data.ethAmountToLock);

        // 清除上一次未成功的验证报告并将预期的 epoch ID 更新为 _epochId。
        _clearReportingAndAdvanceTo(data.epochId + _beaconSpec.epochsPerFrame);

        // report to the dawnPool and collect stats
        IDawnDeposit dawnPool = getDawnDeposit();
//        dawnPool.handleOracleReport(_epochId, _beaconValidators, _beaconBalance, _rewardsVaultBalance, _exitedValidators);
        // todo
        dawnPool.handleOracleReport(data.epochId, data.beaconValidators, data.beaconBalance, data.rewardsVaultBalance, data.exitedValidators,
            data.burnedPEthAmount, data.lastRequestIdToBeFulfilled, data.ethAmountToLock);

    }

    /**
     * @notice 清除上一次未成功的验证报告并将预期的 epoch ID 更新为 _epochId。
     */
    function _clearReportingAndAdvanceTo(uint256 _epochId) internal {
//        REPORTS_BITMASK_POSITION.setStorageUint256(0);
        _setUint(_REPORTS_BITMASK_POSITION, 0);
        _setUint(_EXPECTED_EPOCH_ID_POSITION, _epochId);
//        EXPECTED_EPOCH_ID_POSITION.setStorageUint256(_epochId);
        delete currentReportVariants;
        emit ExpectedEpochIdUpdated(_epochId);
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
     *  通过调用 _getTime() 函数来获取当前区块时间戳，并将其减去 Genesis 时间,除以每个 Epoch 的总时长（即 Slot 时长乘以 Slot 数目）
     * @notice 获取当前时刻所处的 Epoch ID
     */
    function _getCurrentEpochId(BeaconSpec memory _beaconSpec) internal view returns (uint256) {
        return (_getTime() - _beaconSpec.genesisTime) / (_beaconSpec.slotsPerEpoch * _beaconSpec.secondsPerSlot);
    }


    /**
     *  首先通过 _epochId 除以 _beaconSpec.epochsPerFrame 来计算出该 Epoch 所处的 Frame 编号，然后将其乘以 _beaconSpec.epochsPerFrame，即可得到该 Frame 的第一个 Epoch ID
     * @notice Epoch 所属的 Frame 的第一个 Epoch ID
     */
    function _getFrameFirstEpochId(uint256 _epochId, BeaconSpec memory _beaconSpec) internal pure returns (uint256) {
        return _epochId / _beaconSpec.epochsPerFrame * _beaconSpec.epochsPerFrame;
    }

    function getFrameFirstEpochId() external view returns (uint256) {
        BeaconSpec memory beaconSpec = _getBeaconSpec();
        return _getFrameFirstEpochId(_getCurrentEpochId(beaconSpec),beaconSpec);
    }

    /**
     * @notice 获取当前区块时间戳
     */
    function _getTime() internal view returns (uint256) {
        return block.timestamp; // solhint-disable-line not-rely-on-time
    }



}
