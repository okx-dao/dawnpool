// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../base/DawnBase.sol";
import "./DawnPoolOracle.sol";
import "../interface/IHashConsensus.sol";
import "./ReportUtils.sol";
import "../interface/IDepositNodeManager.sol";
import "../interface/IValidatorsExitBusOracle.sol";

contract ValidatorsExitBusOracle is IValidatorsExitBusOracle, DawnBase, ReentrancyGuard {
    constructor(IDawnStorageInterface dawnStorageAddress) DawnBase(dawnStorageAddress) {}

    using ReportUtils for uint256;
    /// @dev Storage slot: uint256 lastProcessingRefSlot
    bytes32 internal constant _LAST_PROCESSING_REF_EPOCH_POSITION =
    keccak256("ValidatorsExitBusOracle._LAST_PROCESSING_REF_EPOCH_POSITION");

    /// Epoch that we currently collect reports
    bytes32 internal constant _EXPECTED_EPOCH_ID_POSITION =
    keccak256("ValidatorsExitBusOracle.EXPECTED_EPOCH_ID_POSITION");

    /// The bitmask of the oracle _members that pushed their reports
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


    /// Maximum number of oracle committee _members
    uint256 public constant MAX_MEMBERS = 256;

    uint256 internal constant _MEMBER_NOT_FOUND = 2 ** 256 - 1;
    /// Contract structured storage
    uint256[] private _currentReportVariants; /// slot 1: reporting storage

    /// Data provider interface
    struct ReportData {
        // 表示报告计算所依据的参考时隙
        uint64 refEpoch;
        // 表示在此报告中相关联的验证器退出请求的总数
        uint32 requestsCount;
        // 表示验证器退出请求数据的格式。目前仅支持 DATA_FORMAT_LIST=1
        //        uint256 dataFormat;
    }


    uint256 public constant DATA_FORMAT_LIST = 1;

    /**
     * @notice Return the DepositNodeManager contract address
     */
    function getDepositNodeManager() public view returns (IDepositNodeManager) {
        return IDepositNodeManager(_getContractAddress("DepositNodeManager"));
    }

    /// 提交报告数据，并进行一些必要的检查和处理操作。合约管理员可以根据需要调用此函数来处理提交的报告数据
    function submitReportData(ReportData calldata data) external nonReentrant{
        BeaconSpec memory beaconSpec = _getBeaconSpec();
        uint256 expectedEpoch = _getUint(_EXPECTED_EPOCH_ID_POSITION);
        //确保传入的_epochId大于等于预期的 epoch ID，以避免提交过时的验证报告
        require(data.refEpoch >= expectedEpoch, "EPOCH_IS_TOO_OLD");

        // if expected epoch has advanced, check that this is the first epoch of the current frame
        // and clear the last unsuccessful reporting
        if (data.refEpoch > expectedEpoch) {
            require(
                data.refEpoch == _getFrameFirstEpochId(_getCurrentEpochId(beaconSpec), beaconSpec),
                "UNEXPECTED_EPOCH"
            );
            //清除上一次未成功的验证报告并将预期的 epoch ID 更新为 _epochId。
            _clearReportingAndAdvanceTo(data.refEpoch);
        }

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
        uint256 report = ReportUtils.encode(data.refEpoch, data.requestsCount);
        // 获取当前所需的最低验证报告数量 quorum
        uint256 quorum = IHashConsensus(_getContractAddressUnsafe("HashConsensus"))
        .getQuorum();
        uint256 i = 0;

        // iterate on all report variants we already have, limited by the oracle _members maximum
        while (i < _currentReportVariants.length && _currentReportVariants[i].isDifferent(report)) ++i;
        if (i < _currentReportVariants.length) {
            // 判断该 variant 的计数器是否已达到要求的数量.达到，则会通过调用 _handleConsensusReportData
            if (_currentReportVariants[i].getCount() + 1 >= quorum) {
                _handleConsensusReportData(data, beaconSpec);
            } else {
                // 增加对应 variant 的报告计数器
                ++_currentReportVariants[i];
            }
        } else {
            // 只需要一个验证报告即可，则直接调用 _push()
            if (quorum == 1) {
                _handleConsensusReportData(data, beaconSpec);
            } else {
                //创建一个新的 variant 并将其添加到 _currentReportVariants 数组中。
                _currentReportVariants.push(report + 1);
            }
        }

    }

    function _handleConsensusReportData(ReportData calldata data, BeaconSpec memory _beaconSpec) internal {
        if (data.requestsCount == 0) {
            return;
        }
        IDepositNodeManager nodeManager = getDepositNodeManager();
        uint256[] memory indexes = nodeManager.updateValidatorsExit(data.requestsCount);

        // 清除上一次未成功的验证报告并将预期的 epoch ID 更新为 refEpoch + epochsPerFrame
        _clearReportingAndAdvanceTo(data.refEpoch + _beaconSpec.epochsPerFrame);
        // 更新上一次成功上报的refEpoch
        _setUint(_LAST_PROCESSING_REF_EPOCH_POSITION, data.refEpoch);
        uint256 timestamp = _getTime();
        // 将验证器退出请求的相关信息转换成事件并派发到链上，以供其他程序查询和使用。
        emit ValidatorExitRequest(data.requestsCount, indexes, timestamp);
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
     * @notice 清除上一次未成功的验证报告并将预期的 epoch ID 更新为 _epochId。
     */
    function _clearReportingAndAdvanceTo(uint256 _epochId) internal {
        _setUint(_REPORTS_BITMASK_POSITION, 0);
        _setUint(_EXPECTED_EPOCH_ID_POSITION, _epochId);
        emit ExpectedEpochIdUpdated(_epochId);
        delete _currentReportVariants;
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
     * @notice Set beacon specification data  定义当前区块链上的信标链规范数据
     */
    function _setBeaconSpec(
        uint64 epochsPerFrame,
        uint64 slotsPerEpoch,
        uint64 secondsPerSlot,
        uint64 genesisTime
    ) internal {
        require(epochsPerFrame > 0, "BAD_EPOCHS_PER_FRAME");
        require(slotsPerEpoch > 0, "BAD_SLOTS_PER_EPOCH");
        require(secondsPerSlot > 0, "BAD_SECONDS_PER_SLOT");
        require(genesisTime > 0, "BAD_GENESIS_TIME");

        uint256 data = ((uint256(epochsPerFrame) << 192) |
        (uint256(slotsPerEpoch) << 128) |
        (uint256(secondsPerSlot) << 64) |
        uint256(genesisTime));
        //        BEACON_SPEC_POSITION.setStorageUint256(data);
        _setUint(_BEACON_SPEC_POSITION, data);
        emit BeaconSpecSet(epochsPerFrame, slotsPerEpoch, secondsPerSlot, genesisTime);
    }

    /**
     * @notice 获取当前报告变量的数量
     */
    function getCurrentReportVariantsSize() external view returns (uint256) {
        return _currentReportVariants.length;
    }

    /**
     * @notice 获取当前 EpochId
     */
    function getCurrentEpochId() external view returns (uint256) {
        BeaconSpec memory beaconSpec = _getBeaconSpec();
        return _getCurrentEpochId(beaconSpec);
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
     *  通过调用 _getTime() 函数来获取当前区块时间戳，并将其减去 Genesis 时间,除以每个 Epoch 的总时长（即 Slot 时长乘以 Slot 数目）
     * @notice 获取当前时刻所处的 Epoch ID
     */
    function _getCurrentEpochId(BeaconSpec memory _beaconSpec) internal view returns (uint256) {
        return (_getTime() - _beaconSpec.genesisTime) / (_beaconSpec.slotsPerEpoch * _beaconSpec.secondsPerSlot);
    }

    function initialize(
        uint64 epochsPerFrame,
        uint64 slotsPerEpoch,
        uint64 secondsPerSlot,
        uint64 genesisTime,
        uint256 lastProcessingRefSlot
    ) external {
        _setUint(_LAST_PROCESSING_REF_EPOCH_POSITION, lastProcessingRefSlot);

        _setBeaconSpec(epochsPerFrame, slotsPerEpoch, secondsPerSlot, genesisTime);

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
        return block.timestamp;
        // solhint-disable-line not-rely-on-time
    }

    /// @notice Returns the last reference slot for which processing of the report was started.
    ///
    function getLastProcessingRefSlot() external view returns (uint256) {
        return _getUint(_LAST_PROCESSING_REF_EPOCH_POSITION);
    }

    function getLastProcessingRefEpoch() external view returns (uint256) {
        return _getUint(_LAST_PROCESSING_REF_EPOCH_POSITION);
    }

    /**
     *  首先通过 _epochId 除以 _beaconSpec.epochsPerFrame 来计算出该 Epoch 所处的 Frame 编号，然后将其乘以 _beaconSpec.epochsPerFrame，即可得到该 Frame 的第一个 Epoch ID
     * todo 取当前Frame的第一帧 忽略 slither 的 performs a multiplication on the result of a division提醒
     */
    function _getFrameFirstEpochId(uint256 _epochId, BeaconSpec memory _beaconSpec) internal pure returns (uint256) {
        return (_epochId / _beaconSpec.epochsPerFrame) * _beaconSpec.epochsPerFrame;
    }

    function getFrameFirstEpochId() external view returns (uint256) {
        BeaconSpec memory beaconSpec = _getBeaconSpec();
        return _getFrameFirstEpochId(_getCurrentEpochId(beaconSpec), beaconSpec);
    }
}
