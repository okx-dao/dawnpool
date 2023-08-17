// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

interface IHashConsensus {

    event MemberAdded(address member);
    event MemberRemoved(address member);
    event QuorumChanged(uint256 quorum);

    /**
     * @notice Return the current oracle member committee list
     */
    function getOracleMembers() external view returns (address[] memory);

    /**
     * @notice Return the current oracle member committee list
     */
    function getMemberId(address addr) external view returns (uint256);

    /**
     * @notice Add `member` to the oracle member committee list
     */
    function addOracleMember(address member) external;

    /**
     * @notice Add `member` to the oracle member committee list
     */
    function removeOracleMember(address member) external;

    /**
     * @notice Return the number of exactly the same reports needed to finalize the epoch
     */
    function getQuorum() external view returns (uint256);

    /**
     * @notice Set the number of exactly the same reports needed to finalize the epoch to `_quorum`
     */
    function setQuorum(uint256 quorum) external;

    function initialize() external;


}
