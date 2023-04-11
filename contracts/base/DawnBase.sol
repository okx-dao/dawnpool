// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDawnStorageInterface.sol";
/// 基础合约（主要实现修饰器方法和通用方法，定义常量、初始化dawnStorage存取数据对象）
abstract contract DawnBase {

    /// 定义ETH计算基础单位 1 ether = 1e18 wei
    uint256 constant CALC_BASE = 1 ether;
    /// 数据存储接口初始化
    IDawnStorageInterface _dawnStorage;

    /// 仅限DawnPool内部合约调用合约方法
    modifier onlyDawnPoolContract() {
        require(getBool(keccak256(abi.encodePacked("contract.exists", msg.sender))), "Invalid or outdated network contract");
        _;
    }

    /// 仅限匹配最新部署的DawnPool合约
    modifier onlyLatestContract(string memory contractName, address contractAddress) {
        require(contractAddress == getAddress(keccak256(abi.encodePacked("contract.address", contractName))), "Invalid or outdated contract");
        _;
    }

    /// 仅匹配初始化设置的监护人地址
    modifier onlyGuardian() {
        require(msg.sender == _dawnStorage.getGuardian(), "Account is not a temporary guardian");
        _;
    }

    /// 构造函数初始化设置dawnStorage合约地址
    constructor(address dawnStorageAddress) {
        _dawnStorage = IDawnStorageInterface(dawnStorageAddress);
    }

    /// 基础方法：通过数据存储的合约名称获取合约地址（排除0x0地址）
    function _getContractAddress(string memory contractName) internal view returns (address) {
        address contractAddress = _getAddress(keccak256(abi.encodePacked("contract.address", contractName)));
        require(contractAddress != address(0x0), "Contract not found");
        return contractAddress;
    }

    /// 基础方法：通过数据存储的合约名称获取合约地址（不排除0x0地址）
    function _getContractAddressUnsafe(string memory contractName) internal view returns (address) {
        address contractAddress = _getAddress(keccak256(abi.encodePacked("contract.address", contractName)));
        return contractAddress;
    }

    /// 基础方法：通过数据存储的合约地址获取合约名称
    function _getContractName(address contractAddress) internal view returns (string memory) {
        string memory contractName = _getString(keccak256(abi.encodePacked("contract.name", contractAddress)));
        require(bytes(contractName).length > 0, "Contract not found");
        return contractName;
    }

    /// DawnStorage方法实现
    function _getAddress(bytes32 key) internal view returns (address) { return _dawnStorage.getAddress(key); }
    function _getUint(bytes32 key) internal view returns (uint) { return _dawnStorage.getUint(key); }
    function _getString(bytes32 key) internal view returns (string memory) { return _dawnStorage.getString(key); }
    function _getBytes(bytes32 key) internal view returns (bytes memory) { return _dawnStorage.getBytes(key); }
    function _getBool(bytes32 key) internal view returns (bool) { return _dawnStorage.getBool(key); }
    function _getInt(bytes32 key) internal view returns (int) { return _dawnStorage.getInt(key); }
    function _getBytes32(bytes32 key) internal view returns (bytes32) { return _dawnStorage.getBytes32(key); }

    function _setAddress(bytes32 key, address value) internal { _dawnStorage.setAddress(key, value); }
    function _setUint(bytes32 key, uint value) internal { _dawnStorage.setUint(key, value); }
    function _setString(bytes32 key, string memory value) internal { _dawnStorage.setString(key, value); }
    function _setBytes(bytes32 key, bytes memory value) internal { _dawnStorage.setBytes(key, value); }
    function _setBool(bytes32 key, bool value) internal { _dawnStorage.setBool(key, value); }
    function _setInt(bytes32 key, int value) internal { _dawnStorage.setInt(key, value); }
    function _setBytes32(bytes32 key, bytes32 value) internal { _dawnStorage.setBytes32(key, value); }

    function _deleteAddress(bytes32 key) internal { _dawnStorage.deleteAddress(key); }
    function _deleteUint(bytes32 key) internal { _dawnStorage.deleteUint(key); }
    function _deleteString(bytes32 key) internal { _dawnStorage.deleteString(key); }
    function _deleteBytes(bytes32 key) internal { _dawnStorage.deleteBytes(key); }
    function _deleteBool(bytes32 key) internal { _dawnStorage.deleteBool(key); }
    function _deleteInt(bytes32 key) internal { _dawnStorage.deleteInt(key); }
    function _deleteBytes32(bytes32 key) internal { _dawnStorage.deleteBytes32(key); }

    function _addUint(bytes32 key, uint256 _amount) internal { _dawnStorage.addUint(key, _amount); }
    function _subUint(bytes32 key, uint256 _amount) internal { _dawnStorage.subUint(key, _amount); }
}
