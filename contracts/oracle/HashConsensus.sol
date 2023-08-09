// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "../interface/IHashConsensus.sol";
import "../base/DawnBase.sol";

contract HashConsensus is IHashConsensus, DawnBase {
    constructor(IDawnStorageInterface dawnStorageAddress) DawnBase(dawnStorageAddress) {}

    /// The bitmask of the oracle _members that pushed their reports
    bytes32 internal constant _REPORTS_BITMASK_POSITION = keccak256("HashConsensus.REPORTS_BITMASK_POSITION");

    /// Maximum number of oracle committee _members
    uint256 public constant MAX_MEMBERS = 256;

    uint256 internal constant _MEMBER_NOT_FOUND = 2 ** 256 - 1;

    bytes32 internal constant _QUORUM_POSITION = keccak256("HashConsensus.QUORUM_POSITION");

    /// Contract structured storage
    address[] private _members; /// slot 0: oracle committee members



    function initialize() external onlyGuardian {
        //Quorum 值用于对 DAO 委员会成员进行投票,将其初始化为 1，表示只需要一个委员会成员的投票即可生效
        emit QuorumChanged(1);
        _setUint(_QUORUM_POSITION, 1);

    }

    /**
     * 添加新的 Oracle 成员
     *
     */
    function addOracleMember(address member) external onlyGuardian {
        require(address(0) != member, "BAD_ARGUMENT");
        require(_MEMBER_NOT_FOUND == getMemberId(member), "MEMBER_EXISTS");
        require(_members.length < MAX_MEMBERS, "TOO_MANY_MEMBERS");

        _members.push(member);

        emit MemberAdded(member);
    }

    /**
     *  删除 Oracle 成员
     *  权限控制onlyGuardian
     */
    function removeOracleMember(address member) external onlyGuardian {
        uint256 index = getMemberId(member);
        require(index != _MEMBER_NOT_FOUND, "MEMBER_NOT_FOUND");
        uint256 last = _members.length - 1;
        if (index != last) _members[index] = _members[last];
        _members[index] = _members[_members.length - 1];
        //        members.length--;
        emit MemberRemoved(member);

        // 该函数在移除 Oracle 成员之后，还需要将与该成员相关的历史验证信息清除 (将存储在合约中的该 Oracle 成员所提交的最后一次验证报告的掩码值设为 0)
        _setUint(_REPORTS_BITMASK_POSITION, 0);

    }

    /**
     * @notice 获取当前 dawnpool 合约的所有 Oracle 成员地址。
     */
    function getOracleMembers() external view returns (address[] memory) {
        return _members;
    }


    /**
     * @notice 取指定成员的 ID
     */
    function getMemberId(address member) public view returns (uint256) {
        uint256 length = _members.length;
        for (uint256 i = 0; i < length; ++i) {
            if (_members[i] == member) {
                return i;
            }
        }
        return _MEMBER_NOT_FOUND;
    }

    /**
     * @notice Return the number of exactly the same reports needed to finalize the epoch
     */
    function getQuorum() public view returns (uint256) {
        return _getUint(_QUORUM_POSITION);
    }

    /**
     * @notice 设置最低投票数量，即 quorum 值
     *
     */
    function setQuorum(uint256 quorum) external onlyGuardian {
        require(0 != quorum, "QUORUM_WONT_BE_MADE");

        emit QuorumChanged(quorum);
        _setUint(_QUORUM_POSITION, quorum);
    }

}
