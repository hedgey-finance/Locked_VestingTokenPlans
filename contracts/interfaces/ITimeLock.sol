// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ITimeLock {
    function createNFT(address recipient, uint256 amount, address token, uint256 unlockDate) external returns (uint256);
    function redeemNFT(uint256 tokenId) external returns (bool);
}