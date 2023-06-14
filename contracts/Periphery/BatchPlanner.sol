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
  
  event BatchCreated(uint8 mintType);

  function batchLockingPlans(
    address locker,
    address token,
    uint256 totalAmount,
    Plan[] memory plans,
    uint256 period,
    uint8 mintType
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
    emit BatchCreated(mintType);
  }

  function batchVestingPlans(
    address locker,
    address token,
    uint256 totalAmount,
    Plan[] memory plans,
    uint256 period,
    address vestingAdmin,
    bool adminTransferOBO,
    uint8 mintType,
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
    emit BatchCreated(mintType);
  }
}
