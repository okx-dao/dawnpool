// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

interface IDawnDepositSecuritymodule {
    struct Signature {
        bytes32 r;
        bytes32 vs;
    }
    event OwnerChanged(address newValue);
    event PauseIntentValidityPeriodBlocksChanged(uint256 newValue);
    event MaxDepositsChanged(uint256 newValue);
    event MinDepositBlockDistanceChanged(uint256 newValue);
    event GuardianQuorumChanged(uint256 newValue);
    event GuardianAdded(address guardian);
    event GuardianRemoved(address guardian);
    event DepositsUnsafeValidator(uint256 indexed index, uint256 indexed slashAmount);

    function getOwner() external view returns (address);

    function setOwner(address newValue) external;

    function getPauseIntentValidityPeriodBlocks() external view returns (uint256);

    function setPauseIntentValidityPeriodBlocks(uint256 newValue) external;

    function getMaxDeposits() external view returns (uint256);

    function setMaxDeposits(uint256 newValue) external;

    function getMinDepositBlockDistance() external view returns (uint256);

    function setMinDepositBlockDistance(uint256 newValue) external;

    function getGuardianQuorum() external view returns (uint256);

    function setGuardianQuorum(uint256 newValue) external;

    function getGuardianAddress(uint256 index) external view returns (address);

    function getGuardiansCount() external view returns (uint256);

    function isGuardian(address addr) external view returns (bool);

    function getGuardianIndex(address addr) external view returns (int256);

    function addGuardian(address addr, uint256 newQuorum) external;

    function addGuardians(address[] memory addresses, uint256 newQuorum) external;

    function removeGuardian(address addr, uint256 newQuorum) external;

    function setValidatorUnsafe(uint256 blockNumber, uint256 index, uint256 slashAmount, Signature memory sig) external;

    function canDeposit() external view returns (bool);

    function depositBufferedEther(
        uint256 blockNumber,
        bytes32 blockHash,
        bytes32 depositRoot,
        uint256[] calldata indexs,
        Signature[] calldata sortedGuardianSignatures
    ) external;

    function getAttestMessagePrefix() external view returns (bytes32);

    function getUnsafeMessagePrefix() external view returns (bytes32);
}
