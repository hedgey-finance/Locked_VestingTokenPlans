// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import './interfaces/ICliffLock.sol';
import './interfaces/ICliffVest.sol';
import './interfaces/IStreamLock.sol';
import './interfaces/IStreamVest.sol';
import './interfaces/ITimeLock.sol';
import './libraries/TransferHelper.sol';

contract MasterBatcher {
  event BatchMinted(address nftLocker, uint256 mintType);

  function createTimeLocks(
    address nftLocker,
    address[] calldata recipients,
    address token,
    uint256[] calldata amounts,
    uint256[] calldata unlocks,
    uint256 mintType
  ) external {
    require(amounts.length == unlocks.length);
    pullTokens(nftLocker, token, amounts, mintType);
    for (uint16 i; i < amounts.length; i++) {
      ITimeLock(nftLocker).createNFT(recipients[i], amounts[i], token, unlocks[i]);
    }
  }

  function createStreamLocks(
    address nftLocker,
    address[] calldata recipients,
    address token,
    uint256[] calldata amounts,
    uint256[] calldata starts,
    uint256[] calldata cliffs,
    uint256[] calldata rates,
    uint256 mintType
  ) external {
    pullTokens(nftLocker, token, amounts, mintType);
    for (uint16 i; i < amounts.length; i++) {
      IStreamLock(nftLocker).createNFT(recipients[i], token, amounts[i], starts[i], cliffs[i], rates[i]);
    }
  }

  function createStreamVests(
    address nftLocker,
    address[] calldata recipients,
    address token,
    uint256[] calldata amounts,
    uint256[] calldata starts,
    uint256[] calldata cliffs,
    uint256[] calldata rates,
    address vestingAdmin,
    uint256[] calldata unlocks,
    uint256 mintType
  ) external {
    uint256 totalAmount;
    {
    for (uint16 i; i < amounts.length; i++) {
      totalAmount += amounts[i];
    }
    TransferHelper.transferTokens(token, msg.sender, address(this), totalAmount);
    SafeERC20.safeIncreaseAllowance(IERC20(token), nftLocker, totalAmount);
    }
    for (uint16 i; i < amounts.length; i++) {
      IStreamVest(nftLocker).createLockedNFT(
        recipients[i],
        token,
        amounts[i],
        starts[i],
        cliffs[i],
        rates[i],
        vestingAdmin,
        unlocks[i],
        true
      );
    }
    emit BatchMinted(nftLocker, mintType);
  }

  function createCliffLocks(
    address nftLocker,
    address[] calldata recipients,
    address token,
    uint256[][] calldata amounts,
    uint256[][] calldata unlocks,
    uint256 mintType
  ) external {
    uint256 totalAmount;
    {
    for (uint16 i; i < amounts.length; i++) {
      for (uint16 j; j < amounts[i].length; j++) {
        totalAmount += amounts[i][j];
      }
    }
    TransferHelper.transferTokens(token, msg.sender, address(this), totalAmount);
    SafeERC20.safeIncreaseAllowance(IERC20(token), nftLocker, totalAmount);
    }
    for (uint16 i; i < amounts.length; i++) {
      ICliffLock(nftLocker).createNFT(recipients[i], token, amounts[i], unlocks[i]);
    }
    emit BatchMinted(nftLocker, mintType);
  }

  function createCliffVests(
    address nftLocker,
    address[] calldata recipients,
    address token,
    uint256[][] calldata amounts,
    uint256[][] calldata unlocks,
    address vestingAdmin,
    uint256[] calldata unlockDates,
    uint256 mintType
  ) external {
    uint256 totalAmount;
    {
    for (uint16 i; i < amounts.length; i++) {
      for (uint16 j; j < amounts[i].length; j++) {
        totalAmount += amounts[i][j];
      }
    }
    TransferHelper.transferTokens(token, msg.sender, address(this), totalAmount);
    SafeERC20.safeIncreaseAllowance(IERC20(token), nftLocker, totalAmount);
    }
    for (uint16 i; i < amounts.length; i++) {
      ICliffVest(nftLocker).createLockedNFT(recipients[i], token, amounts[i], unlocks[i], vestingAdmin, unlockDates[i]);
    }
    emit BatchMinted(nftLocker, mintType);
  }

  function pullTokens(address nftLocker, address token, uint256[] memory amounts, uint256 mintType) internal {
    uint256 totalAmount;
    {
    for (uint16 i; i < amounts.length; i++) {
      totalAmount += amounts[i];
    }
    TransferHelper.transferTokens(token, msg.sender, address(this), totalAmount);
    SafeERC20.safeIncreaseAllowance(IERC20(token), nftLocker, totalAmount);
    }
    emit BatchMinted(nftLocker, mintType);
  }
}
