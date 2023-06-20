// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '../libraries/TransferHelper.sol';
import '../interfaces/IVestingPlans.sol';
import '../interfaces/ILockupPlans.sol';

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
    require(totalAmount > 0, '0_totalAmount');
    require(locker != address(0), '0_locker');
    require(token != address(0), '0_token');
    require(plans.length > 0, 'no plans');
    TransferHelper.transferTokens(token, msg.sender, address(this), totalAmount);
    SafeERC20.safeIncreaseAllowance(IERC20(token), locker, totalAmount);
    uint256 amountCheck;
    for (uint16 i; i < plans.length; i++) {
      ILockupPlans(locker).createPlan(
        plans[i].recipient,
        token,
        plans[i].amount,
        plans[i].start,
        plans[i].cliff,
        plans[i].rate,
        period
      );
      amountCheck += plans[i].amount;
    }
    require(amountCheck == totalAmount, 'totalAmount error');
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
    uint8 mintType
  ) external {
    require(totalAmount > 0, '0_totalAmount');
    require(locker != address(0), '0_locker');
    require(token != address(0), '0_token');
    require(plans.length > 0, 'no plans');
    TransferHelper.transferTokens(token, msg.sender, address(this), totalAmount);
    SafeERC20.safeIncreaseAllowance(IERC20(token), locker, totalAmount);
    uint256 amountCheck;
    for (uint16 i; i < plans.length; i++) {
      IVestingPlans(locker).createPlan(
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
      amountCheck += plans[i].amount;
    }
    require(amountCheck == totalAmount, 'totalAmount error');
    emit BatchCreated(mintType);
  }
}
