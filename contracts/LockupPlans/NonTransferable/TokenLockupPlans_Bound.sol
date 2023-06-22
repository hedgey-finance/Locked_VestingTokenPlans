// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '../TokenLockupPlans.sol';

contract TokenLockupPlans_Bound is TokenLockupPlans {
  constructor(string memory name, string memory symbol) TokenLockupPlans(name, symbol) {}

  function _transfer(address from, address to, uint256 tokenId) internal virtual override {
    revert('Not transferrable');
  }
}
