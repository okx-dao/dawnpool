// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

/// 合约数据存储接口
interface IDawnStorageInterface {
    /// 获取合约已部署状态
    function getDeployedStatus() external view returns (bool);
    /// 获取监护人地址（合约的管理者）
    function getGuardian() external view returns(address);
    /// 设置监护人地址（合约的管理者）
    function setGuardian(address _newAddress) external;
    /// 确认监护人地址
    function confirmGuardian() external;
    /// 获取数据存储的地址
    function getAddress(bytes32 _key) external view returns (address);
    /// 获取Uint类型存储数据
    function getUint(bytes32 _key) external view returns (uint);
    /// 获取String类型存储数据
    function getString(bytes32 _key) external view returns (string memory);
    /// 获取Bytes类型存储数据
    function getBytes(bytes32 _key) external view returns (bytes memory);
    /// 获取Bool类型存储数据
    function getBool(bytes32 _key) external view returns (bool);
    /// 获取Int类型存储数据
    function getInt(bytes32 _key) external view returns (int);
    /// 获取Bytes32类型存储数据
    function getBytes32(bytes32 _key) external view returns (bytes32);

    /// 设置数据存储的地址
    function setAddress(bytes32 _key, address _value) external;
    /// 设置Uint类型存储数据
    function setUint(bytes32 _key, uint _value) external;
    /// 设置String类型存储数据
    function setString(bytes32 _key, string calldata _value) external;
    /// 设置Bytes类型存储数据
    function setBytes(bytes32 _key, bytes calldata _value) external;
    /// 设置Bool类型存储数据
    function setBool(bytes32 _key, bool _value) external;
    /// 设置Int类型存储数据
    function setInt(bytes32 _key, int _value) external;
    /// 设置Bytes32类型存储数据
    function setBytes32(bytes32 _key, bytes32 _value) external;

    /// 清除数据存储的地址
    function deleteAddress(bytes32 _key) external;
    /// 清除Uint类型存储数据
    function deleteUint(bytes32 _key) external;
    /// 清除String数据存储的合约地址
    function deleteString(bytes32 _key) external;
    /// 清除Bytes数据存储的合约地址
    function deleteBytes(bytes32 _key) external;
    /// 清除Bool数据存储的合约地址
    function deleteBool(bytes32 _key) external;
    /// 清除Int数据存储的合约地址
    function deleteInt(bytes32 _key) external;
    /// 清除Bytes32数据存储的合约地址
    function deleteBytes32(bytes32 _key) external;

    /// 支持Uint加法运算
    function addUint(bytes32 _key, uint256 _amount) external;
    /// 支持Uint减法运算
    function subUint(bytes32 _key, uint256 _amount) external;
}
