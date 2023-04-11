// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDawnStorageInterface.sol";
/// 基础合约（主要实现修饰器方法和通用方法，定义常量、初始化dawnStorage存取数据对象）
abstract contract DawnBase {

    /// 定义ETH计算基础单位 1 ether = 1e18 wei
    uint256 constant calcBase = 1 ether;
    /// 数据存储接口初始化
    IDawnStorageInterface dawnStorage = IDawnStorageInterface(address(0));

    /// 仅限DawnPool内部合约调用合约方法
    modifier onlyDawnPoolContract() {
        require(getBool(keccak256(abi.encodePacked("contract.exists", msg.sender))), "Invalid or outdated network contract");
        _;
    }

    /// 仅限匹配最新部署的DawnPool合约
    modifier onlyLatestContract(string memory _contractName, address _contractAddress) {
        require(_contractAddress == getAddress(keccak256(abi.encodePacked("contract.address", _contractName))), "Invalid or outdated contract");
        _;
    }

    /// 仅匹配初始化设置的监护人地址
    modifier onlyGuardian() {
        require(msg.sender == dawnStorage.getGuardian(), "Account is not a temporary guardian");
        _;
    }

    /// 构造函数初始化设置dawnStorage合约地址
    constructor(IDawnStorageInterface _dawnStorageAddress) {
        dawnStorage = IDawnStorageInterface(_dawnStorageAddress);
    }

    /// 基础方法：通过数据存储的合约名称获取合约地址（排除0x0地址）
    function getContractAddress(string memory _contractName) internal view returns (address) {
        address contractAddress = getAddress(keccak256(abi.encodePacked("contract.address", _contractName)));
        require(contractAddress != address(0x0), "Contract not found");
        return contractAddress;
    }

    /// 基础方法：通过数据存储的合约名称获取合约地址（不排除0x0地址）
    function getContractAddressUnsafe(string memory _contractName) internal view returns (address) {
        address contractAddress = getAddress(keccak256(abi.encodePacked("contract.address", _contractName)));
        return contractAddress;
    }

    /// 基础方法：通过数据存储的合约地址获取合约名称
    function getContractName(address _contractAddress) internal view returns (string memory) {
        string memory contractName = getString(keccak256(abi.encodePacked("contract.name", _contractAddress)));
        require(bytes(contractName).length > 0, "Contract not found");
        return contractName;
    }

    /// DawnStorage方法实现
    function getAddress(bytes32 _key) internal view returns (address) { return dawnStorage.getAddress(_key); }
    function getUint(bytes32 _key) internal view returns (uint) { return dawnStorage.getUint(_key); }
    function getString(bytes32 _key) internal view returns (string memory) { return dawnStorage.getString(_key); }
    function getBytes(bytes32 _key) internal view returns (bytes memory) { return dawnStorage.getBytes(_key); }
    function getBool(bytes32 _key) internal view returns (bool) { return dawnStorage.getBool(_key); }
    function getInt(bytes32 _key) internal view returns (int) { return dawnStorage.getInt(_key); }
    function getBytes32(bytes32 _key) internal view returns (bytes32) { return dawnStorage.getBytes32(_key); }

    function setAddress(bytes32 _key, address _value) internal { dawnStorage.setAddress(_key, _value); }
    function setUint(bytes32 _key, uint _value) internal { dawnStorage.setUint(_key, _value); }
    function setString(bytes32 _key, string memory _value) internal { dawnStorage.setString(_key, _value); }
    function setBytes(bytes32 _key, bytes memory _value) internal { dawnStorage.setBytes(_key, _value); }
    function setBool(bytes32 _key, bool _value) internal { dawnStorage.setBool(_key, _value); }
    function setInt(bytes32 _key, int _value) internal { dawnStorage.setInt(_key, _value); }
    function setBytes32(bytes32 _key, bytes32 _value) internal { dawnStorage.setBytes32(_key, _value); }

    function deleteAddress(bytes32 _key) internal { dawnStorage.deleteAddress(_key); }
    function deleteUint(bytes32 _key) internal { dawnStorage.deleteUint(_key); }
    function deleteString(bytes32 _key) internal { dawnStorage.deleteString(_key); }
    function deleteBytes(bytes32 _key) internal { dawnStorage.deleteBytes(_key); }
    function deleteBool(bytes32 _key) internal { dawnStorage.deleteBool(_key); }
    function deleteInt(bytes32 _key) internal { dawnStorage.deleteInt(_key); }
    function deleteBytes32(bytes32 _key) internal { dawnStorage.deleteBytes32(_key); }

    function addUint(bytes32 _key, uint256 _amount) internal { dawnStorage.addUint(_key, _amount); }
    function subUint(bytes32 _key, uint256 _amount) internal { dawnStorage.subUint(_key, _amount); }
}
