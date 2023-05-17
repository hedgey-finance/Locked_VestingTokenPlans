// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

interface IStreamLock {

  function updateBaseURI(string memory _uri) external;

  function createNFT(
    address recipient,
    address token,
    uint256 amount,
    uint256 start,
    uint256 cliffDate,
    uint256 rate
  ) external;

  function redeemAndTransfer(uint256 tokenId, address to) external;

  function redeemNFTs(uint256[] memory tokenIds) external;

  function redeemAllNFTs() external;

  function delegateAllNFTs(address delegate) external;

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
      uint256 rate
    );

  function balanceOf(address holder) external view returns (uint256 balance);

  function ownerOf(uint tokenId) external view returns (address);

}
