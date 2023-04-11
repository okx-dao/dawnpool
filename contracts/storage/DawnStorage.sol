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

    address guardian;
    address newGuardian;

    bool storageInit = false;

    /// 仅允许在部署后从DawnPool最新的合约进行访问
    modifier onlyLatestDawnPoolNetworkContract() {
        if (storageInit == true) {
            require(booleanStorage[keccak256(abi.encodePacked("contract.exists", msg.sender))], "Invalid or outdated network contract");
        } else {
            require((
                booleanStorage[keccak256(abi.encodePacked("contract.exists", msg.sender))] || tx.origin == guardian
                ), "Invalid or outdated network contract attempting access during deployment");
        }
        _;
    }

    constructor() {
        guardian = msg.sender;
    }

    function getGuardian() external override view returns (address) {
        return guardian;
    }

    function setGuardian(address _newAddress) external override {
        require(msg.sender == guardian, "Is not guardian account");
        newGuardian = _newAddress;
    }

    function confirmGuardian() external override {
        require(msg.sender == newGuardian, "Confirmation must come from new guardian address");
        address oldGuardian = guardian;
        guardian = newGuardian;
        delete newGuardian;
        emit GuardianChanged(oldGuardian, guardian);
    }

    function getDeployedStatus() external override view returns (bool) {
        return storageInit;
    }

    function setDeployedStatus() external {
        require(msg.sender == guardian, "Is not guardian account");
        storageInit = true;
    }

    function getAddress(bytes32 _key) override external view returns (address r) {
        return addressStorage[_key];
    }

    function getUint(bytes32 _key) override external view returns (uint256 r) {
        return uintStorage[_key];
    }

    function getString(bytes32 _key) override external view returns (string memory) {
        return stringStorage[_key];
    }

    function getBytes(bytes32 _key) override external view returns (bytes memory) {
        return bytesStorage[_key];
    }

    function getBool(bytes32 _key) override external view returns (bool r) {
        return booleanStorage[_key];
    }

    function getInt(bytes32 _key) override external view returns (int r) {
        return intStorage[_key];
    }

    function getBytes32(bytes32 _key) override external view returns (bytes32 r) {
        return bytes32Storage[_key];
    }

    function setAddress(bytes32 _key, address _value) onlyLatestDawnPoolNetworkContract override external {
        addressStorage[_key] = _value;
    }

    function setUint(bytes32 _key, uint _value) onlyLatestDawnPoolNetworkContract override external {
        uintStorage[_key] = _value;
    }

    function setString(bytes32 _key, string calldata _value) onlyLatestDawnPoolNetworkContract override external {
        stringStorage[_key] = _value;
    }

    function setBytes(bytes32 _key, bytes calldata _value) onlyLatestDawnPoolNetworkContract override external {
        bytesStorage[_key] = _value;
    }

    function setBool(bytes32 _key, bool _value) onlyLatestDawnPoolNetworkContract override external {
        booleanStorage[_key] = _value;
    }

    function setInt(bytes32 _key, int _value) onlyLatestDawnPoolNetworkContract override external {
        intStorage[_key] = _value;
    }

    function setBytes32(bytes32 _key, bytes32 _value) onlyLatestDawnPoolNetworkContract override external {
        bytes32Storage[_key] = _value;
    }

    function deleteAddress(bytes32 _key) onlyLatestDawnPoolNetworkContract override external {
        delete addressStorage[_key];
    }

    function deleteUint(bytes32 _key) onlyLatestDawnPoolNetworkContract override external {
        delete uintStorage[_key];
    }

    function deleteString(bytes32 _key) onlyLatestDawnPoolNetworkContract override external {
        delete stringStorage[_key];
    }

    function deleteBytes(bytes32 _key) onlyLatestDawnPoolNetworkContract override external {
        delete bytesStorage[_key];
    }

    function deleteBool(bytes32 _key) onlyLatestDawnPoolNetworkContract override external {
        delete booleanStorage[_key];
    }

    function deleteInt(bytes32 _key) onlyLatestDawnPoolNetworkContract override external {
        delete intStorage[_key];
    }

    function deleteBytes32(bytes32 _key) onlyLatestDawnPoolNetworkContract override external {
        delete bytes32Storage[_key];
    }

    function addUint(bytes32 _key, uint256 _amount) onlyLatestDawnPoolNetworkContract override external {
        uintStorage[_key] = uintStorage[_key].add(_amount);
    }

    function subUint(bytes32 _key, uint256 _amount) onlyLatestDawnPoolNetworkContract override external {
        uintStorage[_key] = uintStorage[_key].sub(_amount);
    }
}