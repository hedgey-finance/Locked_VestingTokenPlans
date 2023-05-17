// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

interface IStreamVest {
  function updateBaseURI(string memory _uri) external;

  function createNFT(
    address recipient,
    address token,
    uint256 amount,
    uint256 start,
    uint256 cliffDate,
    uint256 rate,
    address vestingAdmin
  ) external;

  function createLockedNFT(
    address recipient,
    address token,
    uint256 amount,
    uint256 start,
    uint256 cliffDate,
    uint256 rate,
    address vestingAdmin,
    uint256 unlockDate,
    bool transferableNFTLockers
  ) external;

  function revokeNFTs(uint256[] memory tokenId) external;

  function redeemNFTs(uint256[] memory tokenId) external;

  function redeemAllNFTs() external;

  function streamBalanceOf(uint256 tokenId) external view returns (uint256 balance, uint256 remainder);

  function getStreamEnd(uint256 tokenId) external view returns (uint256 end);

  function streams(uint256 tokenId)
    external
    view
    returns (
      address token,
      uint256 amount,
      uint256 start,
      uint256 cliffDate,
      uint256 rate,
      address vestingAdmin,
      uint256 unlockDate,
      bool transferableNFTLockers
    );

}
