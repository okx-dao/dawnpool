// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract DawnTokenPETH is ERC20Permit {
    constructor() ERC20Permit("pETH") ERC20("Dawn Pool ETH", "pETH") {}
}
