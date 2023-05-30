// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

library TimelockLibrary {
  function min(uint256 a, uint256 b) internal pure returns (uint256 _min) {
    _min = (a <= b) ? a : b;
  }

  function endDate(uint256 start, uint256 amount, uint256 rate, uint256 period) internal pure returns (uint256 end) {
    end = (amount % rate == 0) ? (amount / rate) * period + start : ((amount / rate) * period + 1) + start;
  }

  function totalPeriods(uint256 rate, uint256 amount) internal pure returns (uint256 periods) {
    periods = amount / rate;
  }

  function balanceAtTime(
    uint256 start,
    uint256 cliffDate,
    uint256 amount,
    uint256 rate,
    uint256 period,
    uint256 time
  ) internal pure returns (uint256 unlockedBalance, uint256 lockedBalance, uint256 unlockTime) {
    if (start > time || cliffDate > time) {
      lockedBalance = amount;
      unlockTime = start;
    } else {
      // should take into account rounding because there are no decimals allowed
      uint256 periodsElapsed = (time - start) / period;
      uint256 calculatedBalance = periodsElapsed * rate;
      unlockedBalance = min(calculatedBalance, amount);
      lockedBalance = amount - unlockedBalance;
      unlockTime = start + (period * periodsElapsed);
    }
  }
}
