// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '../VotingTokenLockupPlans.sol';

contract VotingTokenLockupPlans_Bound is VotingTokenLockupPlans {
  constructor(string memory name, string memory symbol) VotingTokenLockupPlans(name, symbol) {}

  function _transfer(address from, address to, uint256 tokenId) internal virtual override {
    revert('Not transferrable');
  }

  function redeemAndTransfer(uint256 planId, address to) external override {
    revert('Not transferrable');
  }
}
