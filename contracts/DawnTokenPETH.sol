// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DawnTokenPETH is ERC20 {

    constructor() ERC20("Dawn Pool ETH", "pETH") {

    }

}
