pragma solidity ^0.8.17;

// SPDX-License-Identifier: GPL-3.0-only


import "../interface/util/IAddressQueueStorageInterface.sol";

import "../interface/IDawnStorageInterface.sol";
import "../base/DawnBase.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Address queue storage helper for DawnStorage data (ring buffer implementation)

contract AddressQueueStorage is DawnBase, IAddressQueueStorageInterface {

    // Libs
    using SafeMath for uint256;

    // Settings
    uint256 constant public capacity = 2 ** 255; // max uint256 / 2

    // Construct
    constructor(IDawnStorageInterface _dawnStorageAddress) DawnBase(_dawnStorageAddress) {
    }

    // The number of items in a queue
    function getLength(bytes32 _key) override public view returns (uint) {
        uint start = _getUint(keccak256(abi.encodePacked(_key, ".start")));
        uint end = _getUint(keccak256(abi.encodePacked(_key, ".end")));
        if (end < start) { end = end.add(capacity); }
        return end.sub(start);
    }

    // The item in a queue by index
    function getItem(bytes32 _key, uint _index) override external view returns (address) {
        uint index = _getUint(keccak256(abi.encodePacked(_key, ".start"))).add(_index);
        if (index >= capacity) { index = index.sub(capacity); }
        return _getAddress(keccak256(abi.encodePacked(_key, ".item", index)));
    }

    // The index of an item in a queue
    // Returns -1 if the value is not found
    function getIndexOf(bytes32 _key, address _value) override external view returns (int) {
        int index = int(_getUint(keccak256(abi.encodePacked(_key, ".index", _value)))) - 1;
        if (index != -1) {
            index -= int(_getUint(keccak256(abi.encodePacked(_key, ".start"))));
            if (index < 0) { index += int(capacity); }
        }
        return index;
    }

    // Add an item to the end of a queue
    // Requires that the queue is not at capacity
    // Requires that the item does not exist in the queue
    function enqueueItem(bytes32 _key, address _value) override external onlyLatestContract("addressQueueStorage", address(this))  {
        require(getLength(_key) < capacity.sub(1), "Queue is at capacity");
        require(_getUint(keccak256(abi.encodePacked(_key, ".index", _value))) == 0, "Item already exists in queue");
        uint index = _getUint(keccak256(abi.encodePacked(_key, ".end")));
        _setAddress(keccak256(abi.encodePacked(_key, ".item", index)), _value);
        _setUint(keccak256(abi.encodePacked(_key, ".index", _value)), index.add(1));
        index = index.add(1);
        if (index >= capacity) { index = index.sub(capacity); }
        _setUint(keccak256(abi.encodePacked(_key, ".end")), index);
    }

    // Remove an item from the start of a queue and return it
    // Requires that the queue is not empty
    function dequeueItem(bytes32 _key) override external onlyLatestContract("addressQueueStorage", address(this))  returns (address) {
        require(getLength(_key) > 0, "Queue is empty");
        uint start = _getUint(keccak256(abi.encodePacked(_key, ".start")));
        address item = _getAddress(keccak256(abi.encodePacked(_key, ".item", start)));
        start = start.add(1);
        if (start >= capacity) { start = start.sub(capacity); }
        _setUint(keccak256(abi.encodePacked(_key, ".index", item)), 0);
        _setUint(keccak256(abi.encodePacked(_key, ".start")), start);
        return item;
    }

    // Remove an item from a queue
    // Swaps the item with the last item in the queue and truncates it; computationally cheap
    // Requires that the item exists in the queue
    function removeItem(bytes32 _key, address _value) override external onlyLatestContract("addressQueueStorage", address(this))  {
        uint index = _getUint(keccak256(abi.encodePacked(_key, ".index", _value)));
        require(index-- > 0, "Item does not exist in queue");
        uint lastIndex = _getUint(keccak256(abi.encodePacked(_key, ".end")));
        if (lastIndex == 0) lastIndex = capacity;
        lastIndex = lastIndex.sub(1);
        if (index != lastIndex) {
            address lastItem = _getAddress(keccak256(abi.encodePacked(_key, ".item", lastIndex)));
            _setAddress(keccak256(abi.encodePacked(_key, ".item", index)), lastItem);
            _setUint(keccak256(abi.encodePacked(_key, ".index", lastItem)), index.add(1));
        }
        _setUint(keccak256(abi.encodePacked(_key, ".index", _value)), 0);
        _setUint(keccak256(abi.encodePacked(_key, ".end")), lastIndex);
    }

}
