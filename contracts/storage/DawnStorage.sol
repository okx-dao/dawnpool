// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDawnStorageInterface.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// IDawnStorageInterface接口实现类
contract DawnStorage is IDawnStorageInterface {

    /// 监护人权限变更事件
    event GuardianChanged(address oldGuardian, address newGuardian);

    /// 安全的数学方法（比如数据溢出、除0判断等处理）
    using SafeMath for uint256;

    /// key为bytes32、value为字符串
    mapping(bytes32 => string)     private stringStorage;
    mapping(bytes32 => bytes)      private bytesStorage;
    mapping(bytes32 => uint256)    private uintStorage;
    mapping(bytes32 => int256)     private intStorage;
    mapping(bytes32 => address)    private addressStorage;
    mapping(bytes32 => bool)       private booleanStorage;
    mapping(bytes32 => bytes32)    private bytes32Storage;

    address _guardian;
    address _newGuardian;

    bool _storageInit = false;

    /// 仅允许在部署后从DawnPool最新的合约进行访问
    modifier onlyLatestDawnPoolNetworkContract() {
        if (_storageInit == true) {
            require(booleanStorage[keccak256(abi.encodePacked("contract.exists", msg.sender))], "Invalid or outdated network contract");
        } else {
            require((
                booleanStorage[keccak256(abi.encodePacked("contract.exists", msg.sender))] || tx.origin == _guardian
                ), "Invalid or outdated network contract attempting access during deployment");
        }
        _;
    }

    constructor() {
        _guardian = msg.sender;
    }

    function getGuardian() external override view returns (address) {
        return _guardian;
    }

    function setGuardian(address _newAddress) external override {
        require(msg.sender == _guardian, "Is not guardian account");
        _newGuardian = _newAddress;
    }

    function confirmGuardian() external override {
        require(msg.sender == _newGuardian, "Confirmation must come from new guardian address");
        address oldGuardian = _guardian;
        _guardian = _newGuardian;
        delete _newGuardian;
        emit GuardianChanged(oldGuardian, _guardian);
    }

    function getDeployedStatus() external override view returns (bool) {
        return _storageInit;
    }

    function setDeployedStatus() external {
        require(msg.sender == _guardian, "Is not guardian account");
        _storageInit = true;
    }

    function getAddress(bytes32 key) override external view returns (address r) {
        return addressStorage[key];
    }

    function getUint(bytes32 key) override external view returns (uint256 r) {
        return uintStorage[key];
    }

    function getString(bytes32 key) override external view returns (string memory) {
        return stringStorage[key];
    }

    function getBytes(bytes32 key) override external view returns (bytes memory) {
        return bytesStorage[key];
    }

    function getBool(bytes32 key) override external view returns (bool r) {
        return booleanStorage[key];
    }

    function getInt(bytes32 key) override external view returns (int r) {
        return intStorage[key];
    }

    function getBytes32(bytes32 key) override external view returns (bytes32 r) {
        return bytes32Storage[key];
    }

    function setAddress(bytes32 key, address value) onlyLatestDawnPoolNetworkContract override external {
        addressStorage[key] = value;
    }

    function setUint(bytes32 key, uint value) onlyLatestDawnPoolNetworkContract override external {
        uintStorage[key] = value;
    }

    function setString(bytes32 key, string calldata value) onlyLatestDawnPoolNetworkContract override external {
        stringStorage[key] = value;
    }

    function setBytes(bytes32 key, bytes calldata value) onlyLatestDawnPoolNetworkContract override external {
        bytesStorage[key] = value;
    }

    function setBool(bytes32 key, bool value) onlyLatestDawnPoolNetworkContract override external {
        booleanStorage[key] = value;
    }

    function setInt(bytes32 key, int value) onlyLatestDawnPoolNetworkContract override external {
        intStorage[key] = value;
    }

    function setBytes32(bytes32 key, bytes32 value) onlyLatestDawnPoolNetworkContract override external {
        bytes32Storage[key] = value;
    }

    function deleteAddress(bytes32 key) onlyLatestDawnPoolNetworkContract override external {
        delete addressStorage[key];
    }

    function deleteUint(bytes32 key) onlyLatestDawnPoolNetworkContract override external {
        delete uintStorage[key];
    }

    function deleteString(bytes32 key) onlyLatestDawnPoolNetworkContract override external {
        delete stringStorage[key];
    }

    function deleteBytes(bytes32 key) onlyLatestDawnPoolNetworkContract override external {
        delete bytesStorage[key];
    }

    function deleteBool(bytes32 key) onlyLatestDawnPoolNetworkContract override external {
        delete booleanStorage[key];
    }

    function deleteInt(bytes32 key) onlyLatestDawnPoolNetworkContract override external {
        delete intStorage[key];
    }

    function deleteBytes32(bytes32 key) onlyLatestDawnPoolNetworkContract override external {
        delete bytes32Storage[key];
    }

    function addUint(bytes32 key, uint256 amount) onlyLatestDawnPoolNetworkContract override external {
        uintStorage[key] = uintStorage[key].add(amount);
    }

    function subUint(bytes32 key, uint256 amount) onlyLatestDawnPoolNetworkContract override external {
        uintStorage[key] = uintStorage[key].sub(amount);
    }
}
