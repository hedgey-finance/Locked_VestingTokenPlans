// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ICliffLock {
  function createNFT(address recipient, address token, uint256[] calldata amounts, uint256[] calldata unlocks) external;

  function partialRedeemNFT(uint256 tokenId, uint16 unlocks) external;

  function redeemNFTs(uint256[] memory tokenIds) external;

  function redeemableBalance(uint256 tokenId) external view returns (uint256 balance, uint16 redeemableCliffs);
}
