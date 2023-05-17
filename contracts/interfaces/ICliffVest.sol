// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ICliffVest {
  function createNFT(
    address recipient,
    address token,
    uint256[] calldata amounts,
    uint256[] calldata unlocks,
    address vestingAdmin
  ) external;

  function createLockedNFT(
    address recipient,
    address token,
    uint256[] calldata amounts,
    uint256[] calldata unlocks,
    address vestingAdmin,
    uint256 unlockDate
  ) external;

  function partialRedeemNFT(uint256 tokenId, uint16 unlocks) external;

  function redeemNFTs(uint256[] calldata tokenIds) external;

  function revokeNFTs(uint256[] memory tokenIds) external;

  function redeemableBalance(uint256 tokenId) external view returns (uint256 balance, uint16 redeemableCliffs);
}
