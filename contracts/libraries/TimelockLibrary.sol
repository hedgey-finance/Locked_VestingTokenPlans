// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

library TimelockLibrary {
  function min(uint256 a, uint256 b) internal pure returns (uint256 _min) {
    _min = (a <= b) ? a : b;
  }

  function endDate(uint256 start, uint256 amount, uint256 rate, uint256 interval) internal pure returns (uint256 end) {
    end = (amount / rate) * interval + start;
  }

  function totalPeriods(uint256 rate, uint256 amount) internal pure returns (uint256 periods) {
    periods = amount / rate;
  }

  function balanceAtTime(
    uint256 start,
    uint256 cliffDate,
    uint256 amount,
    uint256 rate,
    uint256 interval,
    uint256 time
  ) internal pure returns (uint256 unlockedBalance, uint256 lockedBalance) {
    if (start > time || cliffDate > time) lockedBalance = amount;
    else {
      // should take into account rounding because there are no decimals allowed
      uint256 calculatedBalance = ((time - start) / interval) * rate;
      unlockedBalance = min(calculatedBalance, amount);
      lockedBalance = amount - unlockedBalance;
    }
  }
}
