// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDawnStorageInterface.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../interface/IDawnDeposit.sol";
import "../interface/IDepositContract.sol";
import "../interface/IDepositNodeManager.sol";
import "../base/DawnBase.sol";
import "../interface/util/IAddressSetStorageInterface.sol";
import "../interface/IDawnDepositSecurityModule.sol";

contract DawnDepositSecurityModule is DawnBase,IDawnDepositSecuritymodule {
    /**
  * Short ECDSA signature as defined in https://eips.ethereum.org/EIPS/eip-2098.
  */

    error ZeroAddress(string field);
    error DuplicateAddress(address addr);
    error NotAnOwner(address caller);
    error InvalidSignature();
    error SignaturesNotSorted();
    error DepositNoQuorum();
    error DepositRootChanged();
    error DepositInactiveModule();
    error DepositTooFrequent();
    error DepositUnexpectedBlockHash();
    error DepositNonceChanged();
    error PauseIntentExpired();
    error NotAGuardian(address addr);
    error ZeroParameter(string parameter);

    bytes32 public immutable ATTEST_MESSAGE_PREFIX;
    bytes32 public immutable UNSAFE_MESSAGE_PREFIX;
    // keccak256("dawnPool.DepositSecurityModule.OWNER")
    bytes32 public constant  OWNER_HASH=0xc9251fa75af76049a46c72a1940af4a2dfa80228a9f60ce95cf8b12dc69459c8;
    // keccak256("dawnPool.DepositSecurityModule.PAUSE_INTENT_VALIDITY_PERIOD_BLOCK")
    bytes32 public constant PAUSE_INTENT_VALIDITY_PEROID_BLOCKS_HASH=0x2e72a31c4de4682215c3b4bdfaf159f81858efb221c2576e36a9218a0f909ace;
    // keccak256("dawnPool.DepositSecurityModule.MAX_DEPOSITS_BLOCK")
    bytes32 public constant MAX_DEPOSITS_BLOCK_HASH = 0x5c526a55ec962481ceee5f6e29b0bf6e8f21c4afc918115a21f225aa56b40e09;
    // keccak256("dawnPool.DepositSecurityModule.MIN_DEPOSIT_BLOCK_DISTANCE")
    bytes32 public constant MIN_DEPOSIT_BLOCK_DISTANCE_HASH = 0xe36e3ab7618b1a09fe366e20a6f0cb9b9704c59d7f3131ac3bbb6b98f7c60098;
    // keccak256("dawnPool.DepositSecurityModule.GUARDIAN_QUORUM")
    bytes32 public constant GUARDIAN_QUORUM_HASH =0x62db56b7c289e6ee0047a0bb6a603e88fa085bce071aaa0d9bf3bbde47f0ffa4;
    // keccak256("dawnPool.DepositSecurityModule.DEPOSIT_SECURITY_MODULE_GUARDIAN_ADDRESS")
    bytes32 public constant DEPOSIT_SECURITY_MODULE_GUARDIAN_ADDRESS_HASH = 0xa1f08e983736e93ab9eb200bf38d5e7f87bc8b9791bcd8802141baf806cdeada;
    // keccak256("dawnPool.DepositSecurityModule.LAST_DEPOSIT_BLOCK_HASH")
    bytes32 public constant LAST_DEPOSIT_BLOCK_HASH =0xa625831c7f31baad268665cfdba1031924ca705cf0a724acc0ec51ec366fa049;


    string internal constant _DAWN_DEPOSIT_CONTRACT_NAME = "DawnDeposit";
    string internal constant _DEPOSIT_NODE_MANAGER_CONTRACT_NAME = "DepositNodeManager";
    string internal constant _ADDRESS_SET_STORAGE_CONTRACT_NAME = "AddressSetStorage";
    IDepositContract public immutable depositContract;





    constructor(
        IDawnStorageInterface _depositStorage,
        address _depositContract
    ) DawnBase(_depositStorage){
        if (_depositContract == address(0)) revert ZeroAddress ("_depositContract");

        depositContract = IDepositContract(_depositContract);

        ATTEST_MESSAGE_PREFIX = keccak256(
            abi.encodePacked(
            // keccak256("dawnPool.DepositSecurityModule.ATTEST_MESSAGE")
                bytes32(0x8afecddbaa398e929a3891f0f7dda5f46936f18a4c1058906db377f31b287cc2),
                block.chainid,
                address(this)
            )
        );

        UNSAFE_MESSAGE_PREFIX = keccak256(
            abi.encodePacked(
            // keccak256("dawnPool.DepositSecurityModule.UNSAFE_MESSAGE_PREFIX")
                bytes32(0xc1e6e246775e544affa47870fa3f1270d88e5f8b01f4fd1f926604f62501ab5c),
                block.chainid,
                address(this)
            )
        );
    }

    function initilize( uint256 _maxDepositsPerBlock,
        uint256 _minDepositBlockDistance,
        uint256 _pauseIntentValidityPeriodBlocks
    ) external  {
        _setOwner(msg.sender);
        _setMaxDeposits(_maxDepositsPerBlock);
        _setMinDepositBlockDistance(_minDepositBlockDistance);
        _setPauseIntentValidityPeriodBlocks(_pauseIntentValidityPeriodBlocks);
    }

    function getAttestMessagePrefix() external view returns (bytes32) {
        return ATTEST_MESSAGE_PREFIX;
    }
    function getUnsafeMessagePrefix() external view returns (bytes32) {
        return UNSAFE_MESSAGE_PREFIX;
    }

    function getOwner() external view returns (address) {
          return _getOwner();
    }
    function _getOwner() internal view returns (address){
        return _getAddress(OWNER_HASH);
    }

    modifier onlyOwner() {
        if (msg.sender != _getOwner()) revert NotAnOwner(msg.sender);
        _;
    }

    /**
     * Sets new owner. Only callable by the current owner.
     */
    function setOwner(address newValue) external onlyOwner {
        _setOwner(newValue);
    }

    function _setOwner(address _newOwner) internal {
        if (_newOwner == address(0)) revert ZeroAddress("_newOwner");
        _setAddress(OWNER_HASH,_newOwner);
        emit OwnerChanged(_newOwner);
    }


    function getPauseIntentValidityPeriodBlocks() external view returns (uint256) {
        return _getPauseIntentValidityPeriodBlocks();
    }
    function _getPauseIntentValidityPeriodBlocks() internal view returns (uint256) {
        return _getUint(PAUSE_INTENT_VALIDITY_PEROID_BLOCKS_HASH);
    }

    /**
     * Sets `pauseIntentValidityPeriodBlocks`. Only callable by the owner.
     */
    function setPauseIntentValidityPeriodBlocks(uint256 newValue) external onlyOwner {
        _setPauseIntentValidityPeriodBlocks(newValue);
    }

    function _setPauseIntentValidityPeriodBlocks(uint256 newValue) internal {
        if (newValue == 0) revert ZeroParameter("pauseIntentValidityPeriodBlocks");
        _setUint(PAUSE_INTENT_VALIDITY_PEROID_BLOCKS_HASH, newValue);
        emit PauseIntentValidityPeriodBlocksChanged(newValue);
    }


    function getMaxDeposits() external view returns (uint256) {
        return _getMaxDeposits();
    }

    function _getMaxDeposits() internal view returns (uint256) {
        return _getUint(MAX_DEPOSITS_BLOCK_HASH);
    }

    /**
     * Sets `maxDepositsPerBlock`. Only callable by the owner.
     *
     * NB: the value must be harmonized with `OracleReportSanityChecker.churnValidatorsPerDayLimit`
     * (see docs for the `OracleReportSanityChecker.setChurnValidatorsPerDayLimit` function)
     */
    function setMaxDeposits(uint256 newValue) external onlyOwner {
        _setMaxDeposits(newValue);
    }

    function _setMaxDeposits(uint256 newValue) internal {
        _setUint(MAX_DEPOSITS_BLOCK_HASH, newValue);
        emit MaxDepositsChanged(newValue);
    }

    function _getDawnDeposit() internal  view returns (address){
        return _getContractAddress(_DAWN_DEPOSIT_CONTRACT_NAME);
    }

    function _getDepositNodeManager() internal  view returns (address){
        return _getContractAddress(_DEPOSIT_NODE_MANAGER_CONTRACT_NAME);
    }

    function _getAddressSetStorage() internal  view returns (address){
        return _getContractAddress(_ADDRESS_SET_STORAGE_CONTRACT_NAME);
    }

    function getMinDepositBlockDistance() external view returns (uint256) {
        return _getMinDepositBlockDistance();
    }

    function _getMinDepositBlockDistance() internal view returns (uint256) {
        return _getUint(MIN_DEPOSIT_BLOCK_DISTANCE_HASH);
    }

    /**
     * Sets `minDepositBlockDistance`. Only callable by the owner.
     *
     * NB: the value must be harmonized with `OracleReportSanityChecker.churnValidatorsPerDayLimit`
     * (see docs for the `OracleReportSanityChecker.setChurnValidatorsPerDayLimit` function)
     */
    function setMinDepositBlockDistance(uint256 newValue) external onlyOwner {
        _setMinDepositBlockDistance(newValue);
    }

    function _setMinDepositBlockDistance(uint256 newValue) internal {
        if (newValue == 0) revert ZeroParameter("minDepositBlockDistance");
        if (newValue != _getMinDepositBlockDistance()) {
            _setUint(MIN_DEPOSIT_BLOCK_DISTANCE_HASH, newValue);
            emit MinDepositBlockDistanceChanged(newValue);
        }
    }

    function getGuardianQuorum() external view returns (uint256) {
        return _getGuardianQuorum();
    }

    function _getGuardianQuorum() internal view returns (uint256) {
        return _getUint(GUARDIAN_QUORUM_HASH);
    }
    function setGuardianQuorum(uint256 newValue) external onlyOwner {
        _setGuardianQuorum(newValue);
    }

    function _setGuardianQuorum(uint256 newValue) internal {
        // we're intentionally allowing setting quorum value higher than the number of guardians
        if (_getGuardianQuorum() != newValue) {
            _setUint(GUARDIAN_QUORUM_HASH,newValue);
            emit GuardianQuorumChanged(newValue);
        }
    }



    function getGuardianAddress(uint256 index) external view returns (address) {
        return _getGuardianAddress(index);
    }
    function _getGuardianAddress(uint256 index) internal view returns (address) {
        return   IAddressSetStorageInterface(_getAddressSetStorage())
        .getItem(DEPOSIT_SECURITY_MODULE_GUARDIAN_ADDRESS_HASH,index);
    }

    function getGuardiansCount() external view returns (uint256) {
        return _getGuardiansCount();
    }
    function _getGuardiansCount() internal view returns (uint256) {
        return  IAddressSetStorageInterface(_getAddressSetStorage())
        .getCount(DEPOSIT_SECURITY_MODULE_GUARDIAN_ADDRESS_HASH);
    }
    /**
     * Checks whether the given address is a guardian.
     */
    function isGuardian(address addr) external view returns (bool) {
        return _isGuardian(addr);
    }

    function _isGuardian(address addr) internal view returns (bool) {
        return _getGuardianIndex(addr) > -1;
    }

    /**
     * Returns index of the guardian, or -1 if the address is not a guardian.
     */
    function getGuardianIndex(address addr) external view returns (int256) {
        return _getGuardianIndex(addr);
    }

    function _getGuardianIndex(address addr) internal view returns (int256) {
        return  IAddressSetStorageInterface(_getAddressSetStorage())
        .getIndexOf(DEPOSIT_SECURITY_MODULE_GUARDIAN_ADDRESS_HASH,addr);
    }

    /**
     * Adds a guardian address and sets a new quorum value.
     * Reverts if the address is already a guardian.
     *
     * Only callable by the owner.
     */
    function addGuardian(address addr, uint256 newQuorum) external onlyOwner {
        _addGuardian(addr);
        _setGuardianQuorum(newQuorum);
    }

    /**
     * Adds a set of guardian addresses and sets a new quorum value.
     * Reverts any of them is already a guardian.
     *
     * Only callable by the owner.
     */
    function addGuardians(address[] memory addresses, uint256 newQuorum) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; ++i) {
            _addGuardian(addresses[i]);
        }
        _setGuardianQuorum(newQuorum);
    }

    function _addGuardian(address _newGuardian) internal {
        if (_newGuardian == address(0)) revert ZeroAddress("_newGuardian");
        if (_isGuardian(_newGuardian)) revert DuplicateAddress(_newGuardian);
        IAddressSetStorageInterface(_getAddressSetStorage())
        .addItem(DEPOSIT_SECURITY_MODULE_GUARDIAN_ADDRESS_HASH,_newGuardian);
        emit GuardianAdded(_newGuardian);
    }

    /**
     * Removes a guardian with the given address and sets a new quorum value.
     *
     * Only callable by the owner.
     */
    function removeGuardian(address addr, uint256 newQuorum) external onlyOwner {
        IAddressSetStorageInterface addressSetStorage = IAddressSetStorageInterface(_getAddressSetStorage());
        int256 indexOneBased =  addressSetStorage.getIndexOf(DEPOSIT_SECURITY_MODULE_GUARDIAN_ADDRESS_HASH,addr);
        if (indexOneBased < 0) revert NotAGuardian(addr);

        uint256 totalGuardians = _getGuardiansCount();
        assert(uint256(indexOneBased) <= totalGuardians);

        addressSetStorage.removeItem(DEPOSIT_SECURITY_MODULE_GUARDIAN_ADDRESS_HASH,addr);


        _setGuardianQuorum(newQuorum);

        emit GuardianRemoved(addr);
    }

    /**
     * Pauses deposits for staking module given that both conditions are satisfied (reverts otherwise):
     *
     *   1. The function is called by the guardian with index guardianIndex OR sig
     *      is a valid signature by the guardian with index guardianIndex of the data
     *      defined below.
     *
     *   2. block.number - blockNumber <= pauseIntentValidityPeriodBlocks
     *
     * The signature, if present, must be produced for keccak256 hash of the following
     * message (each component taking 32 bytes):
     *
     * | UNSAFE_MESSAGE_PREFIX | blockNumber | index| slashAmount
     */
    function setValidatorUnsafe(
        uint256 blockNumber,
        uint256 index,
        uint256 slashAmount,
        Signature memory sig
    ) external {
        // In case of an emergency function `pauseDeposits` is supposed to be called
        // by all guardians. Thus only the first call will do the actual change. But
        // the other calls would be OK operations from the point of view of protocol’s logic.
        // Thus we prefer not to use “error” semantics which is implied by `require`.

        /// @dev pause only active modules (not already paused, nor full stopped)


        address guardianAddr = msg.sender;
        int256 guardianIndex = _getGuardianIndex(msg.sender);

        if (guardianIndex == -1) {
            bytes32 msgHash = keccak256(abi.encodePacked(UNSAFE_MESSAGE_PREFIX, blockNumber,index,slashAmount));
            guardianAddr = ECDSA.recover(msgHash, sig.r, sig.vs);
            guardianIndex = _getGuardianIndex(guardianAddr);
            if (guardianIndex == -1) revert InvalidSignature();
        }

        if (block.number - blockNumber >  _getPauseIntentValidityPeriodBlocks()) revert PauseIntentExpired();

        IDepositNodeManager(_getDepositNodeManager()).setValidatorUnsafe(index,slashAmount);
        emit DepositsUnsafeValidator(index, slashAmount);
    }

    function _getLastDepositBlock()  internal view returns (uint256){
        return _getUint(LAST_DEPOSIT_BLOCK_HASH);
    }
    function _setLastDepositBlock(uint256 newValue)  internal {
        return _setUint(LAST_DEPOSIT_BLOCK_HASH,newValue);
    }

    function canDeposit() external view returns (bool) {

        bool isCanDeposit =  IDawnDeposit(_getDawnDeposit()).getBufferedEther() >= 31000000000000000000;
        return (
            _getGuardianQuorum() > 0
            && block.number -  _getLastDepositBlock() >= _getMinDepositBlockDistance()
            && isCanDeposit
        );
    }

    /**
     * Calls DawnNodeOperator.deposit(maxDepositsPerBlock, stakingModuleId, depositCalldata).
     *
     * Reverts if any of the following is true:
     *   1. IDepositContract.get_deposit_root() != depositRoot.
     *   2. StakingModule.getNonce() != nonce.
     *   3. The number of guardian signatures is less than getGuardianQuorum().
     *   4. An invalid or non-guardian signature received.
     *   5. block.number - StakingModule.getLastDepositBlock() < minDepositBlockDistance.
     *   6. blockhash(blockNumber) != blockHash.
     *
     * Signatures must be sorted in ascending order by address of the guardian. Each signature must
     * be produced for the keccak256 hash of the following message (each component taking 32 bytes):
     *
     * | ATTEST_MESSAGE_PREFIX | blockNumber | blockHash | depositRoot | index |
     */
    function depositBufferedEther(
        uint256 blockNumber,
        bytes32 blockHash,
        bytes32 depositRoot,
        uint256[] calldata indexs,
        Signature[] calldata sortedGuardianSignatures
    ) external {
        if (_getGuardianQuorum() == 0 || sortedGuardianSignatures.length < _getGuardianQuorum()) revert DepositNoQuorum();

        bytes32 onchainDepositRoot = IDepositContract(depositContract).get_deposit_root();
        if (depositRoot != onchainDepositRoot) revert DepositRootChanged();
        IDepositNodeManager depositNodeManager = IDepositNodeManager(_getDepositNodeManager());
        IDepositNodeManager.ValidatorStatus temp;
        uint256 i=0;
        for(i=0;i<indexs.length ;i++){
            (,,temp)= depositNodeManager.getNodeValidator(indexs[i]);
            if (temp!=IDepositNodeManager.ValidatorStatus.WAITING_ACTIVATED)  revert DepositInactiveModule();
        }

        if (block.number - _getLastDepositBlock() < _getMinDepositBlockDistance()) revert DepositTooFrequent();
        if (blockHash == bytes32(0) || blockhash(blockNumber) != blockHash) revert DepositUnexpectedBlockHash();



        _verifySignatures(depositRoot, blockNumber, blockHash, indexs, sortedGuardianSignatures);

        depositNodeManager.activateValidators(indexs);

        _setLastDepositBlock( blockNumber);
    }
    function _verifySignatures(
        bytes32 depositRoot,
        uint256 blockNumber,
        bytes32 blockHash,
        uint256[]  memory indexs,
        Signature[] memory sigs
    ) internal view {
        bytes32 msgHash = keccak256(
            abi.encodePacked(ATTEST_MESSAGE_PREFIX, blockNumber, blockHash, depositRoot, indexs)
        );

        address prevSignerAddr = address(0);

        for (uint256 i = 0; i < sigs.length; ++i) {
            address signerAddr = ECDSA.recover(msgHash, sigs[i].r, sigs[i].vs);
            if (!_isGuardian(signerAddr)) revert InvalidSignature();
            if (signerAddr <= prevSignerAddr) revert SignaturesNotSorted();
            prevSignerAddr = signerAddr;
        }
    }
}
