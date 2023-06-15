pragma solidity ^0.8.17;

// SPDX-License-Identifier: GPL-3.0-only

import "../interface/util/IAddressSetStorageInterface.sol";

import "../base/DawnBase.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Address set storage helper for RocketStorage data (contains unique items; has reverse index lookups)

contract AddressSetStorage is DawnBase, IAddressSetStorageInterface {

    using SafeMath for uint;

    // Construct
    constructor(IDawnStorageInterface _dawnStorageAddress) DawnBase(_dawnStorageAddress) {
    }

    // The number of items in a set
    function getCount(bytes32 _key) override external view returns (uint) {
        return _getUint(keccak256(abi.encodePacked(_key, ".count")));
    }

    // The item in a set by index
    function getItem(bytes32 _key, uint _index) override external view returns (address) {
        return _getAddress(keccak256(abi.encodePacked(_key, ".item", _index)));
    }

    // The index of an item in a set
    // Returns -1 if the value is not found
    function getIndexOf(bytes32 _key, address _value) override external view returns (int) {
        return int(_getUint(keccak256(abi.encodePacked(_key, ".index", _value)))) - 1;
    }

    // Add an item to a set
    // Requires that the item does not exist in the set
    function addItem(bytes32 _key, address _value) override external onlyLatestContract("addressSetStorage", address(this))  {
        require(_getUint(keccak256(abi.encodePacked(_key, ".index", _value))) == 0, "Item already exists in set");
        uint count = _getUint(keccak256(abi.encodePacked(_key, ".count")));
        _setAddress(keccak256(abi.encodePacked(_key, ".item", count)), _value);
        _setUint(keccak256(abi.encodePacked(_key, ".index", _value)), count.add(1));
        _setUint(keccak256(abi.encodePacked(_key, ".count")), count.add(1));
    }

    // Remove an item from a set
    // Swaps the item with the last item in the set and truncates it; computationally cheap
    // Requires that the item exists in the set
    function removeItem(bytes32 _key, address _value) override external onlyLatestContract("addressSetStorage", address(this))  {
        uint256 index = _getUint(keccak256(abi.encodePacked(_key, ".index", _value)));
        require(index-- > 0, "Item does not exist in set");
        uint count = _getUint(keccak256(abi.encodePacked(_key, ".count")));
        if (index < count.sub(1)) {
            address lastItem = _getAddress(keccak256(abi.encodePacked(_key, ".item", count.sub(1))));
            _setAddress(keccak256(abi.encodePacked(_key, ".item", index)), lastItem);
            _setUint(keccak256(abi.encodePacked(_key, ".index", lastItem)), index.add(1));
        }
        _setUint(keccak256(abi.encodePacked(_key, ".index", _value)), 0);
        _setUint(keccak256(abi.encodePacked(_key, ".count")), count.sub(1));
    }

}
