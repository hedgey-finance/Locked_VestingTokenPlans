// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import './HedgeyCliffLocks.sol';

contract HedgeyBoundCliffLocks is HedgeyCliffLocks {
    constructor(string memory name, string memory symbol) HedgeyCliffLocks(name, symbol) {}

    /// @dev these NFTs cannot be transferred
  function _transfer(address from, address to, uint256 tokenId) internal virtual override {
    revert('Not transferrable');
  }
}