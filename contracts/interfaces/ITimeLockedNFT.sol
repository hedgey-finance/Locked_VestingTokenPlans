// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

interface ITimeLockedNFT {

  function createNFT(
    address recipient,
    address token,
    uint256 amount,
    uint256 start,
    uint256 cliff,
    uint256 rate,
    uint256 interval
  ) external;

}
