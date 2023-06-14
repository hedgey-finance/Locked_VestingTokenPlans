// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '../libraries/TransferHelper.sol';
import '../interfaces/IVestingTokenPlans.sol';
import '../interfaces/ILockedTokenPlans.sol';

contract BatchPlanner {
  struct Plan {
    address recipient;
    uint256 amount;
    uint256 start;
    uint256 cliff;
    uint256 rate;
  }

  function batchLockingPlans(
    address locker,
    address token,
    uint256 totalAmount,
    Plan[] memory plans,
    uint256 period
  ) external {
    TransferHelper.transferTokens(token, msg.sender, address(this), totalAmount);
    SafeERC20.safeIncreaseAllowance(IERC20(token), locker, totalAmount);
    for (uint16 i; i < plans.length; i++) {
      ILockedTokenPlans(locker).createPlan(
        plans[i].recipient,
        token,
        plans[i].amount,
        plans[i].start,
        plans[i].cliff,
        plans[i].rate,
        period
      );
    }
  }

  function batchVestingPlans(
    address locker,
    address token,
    uint256 totalAmount,
    Plan[] memory plans,
    uint256 period,
    address vestingAdmin,
    bool adminTransferOBO
  ) external {
    TransferHelper.transferTokens(token, msg.sender, address(this), totalAmount);
    SafeERC20.safeIncreaseAllowance(IERC20(token), locker, totalAmount);
    for (uint16 i; i < plans.length; i++) {
      IVestingTokenPlans(locker).createPlan(
        plans[i].recipient,
        token,
        plans[i].amount,
        plans[i].start,
        plans[i].cliff,
        plans[i].rate,
        period,
        vestingAdmin,
        adminTransferOBO
      );
    }
  }
}
