// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDawnTreasury.sol";
import "../base/DawnBase.sol";

contract DawnTreasury is IDawnTreasury, DawnBase {
    constructor(IDawnStorageInterface dawnStorageAddress) DawnBase(dawnStorageAddress) {}
}
