// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

library TimelockLibrary {
  function min(uint256 a, uint256 b) internal pure returns (uint256 _min) {
    _min = (a <= b) ? a : b;
  }

  function endDate(uint256 start, uint256 amount, uint256 rate, uint256 period) internal pure returns (uint256 end) {
    end = (amount % rate == 0) ? (amount / rate) * period + start : ((amount / rate) * period) + period + start;
  }

  function validateEnd(uint256 start, uint256 cliff, uint256 amount, uint256 rate, uint256 period) internal pure returns (uint256 end, bool valid) {
    require(amount > 0, 'amount error');
    require(rate > 0, 'rate error');
    require(rate <= amount, 'rate-amount');
    require(period > 0, 'period error');
    end = (amount % rate == 0) ? (amount / rate) * period + start : ((amount / rate) * period) + period + start;
    require(cliff <= end, 'SV12');
    valid = true;
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
    uint256 currentTime,
    uint256 redemptionTime
  ) internal pure returns (uint256 unlockedBalance, uint256 lockedBalance, uint256 unlockTime) {
    if (start > currentTime || cliffDate > currentTime) {
      lockedBalance = amount;
      unlockTime = start;
    } else {
      // should take into account rounding because there are no decimals allowed
      uint256 periodsElapsed = (redemptionTime - start) / period;
      uint256 calculatedBalance = periodsElapsed * rate;
      unlockedBalance = min(calculatedBalance, amount);
      lockedBalance = amount - unlockedBalance;
      unlockTime = start + (period * periodsElapsed);
    }
  }
}
