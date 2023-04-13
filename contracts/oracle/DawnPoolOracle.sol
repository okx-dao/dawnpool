// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDawnPoolOracle.sol";
import "../base/DawnBase.sol";

contract DawnPoolOracle is IDawnPoolOracle, DawnBase {
    constructor(IDawnStorageInterface dawnStorageAddress) DawnBase(dawnStorageAddress) {}
}
