// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "../interface/IDawnStorageInterface.sol";
import "../base/DawnBase.sol";

contract DawnVault is DawnBase {

    constructor(IDawnStorageInterface dawnStorageAddress) DawnBase(dawnStorageAddress) {

    }
}