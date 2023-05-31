// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import './libraries/TransferHelper.sol';
import './interfaces/IVestingTokenPlans.sol';
import './interfaces/ILockedTokenPlans.sol';

interface ILinearLock {
  function createNFT(
    address recipient,
    address token,
    uint256 amount,
    uint256 start,
    uint256 cliffDate,
    uint256 rate
  ) external;
}

interface ILinearVester {
  function createNFT(
    address recipient,
    address token,
    uint256 amount,
    uint256 start,
    uint256 cliffDate,
    uint256 rate,
    address vestingAdmin
  ) external;
}

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
    address vestingAdmin
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
        vestingAdmin
      );
    }
  }

  function batchLinearPlan(address locker, address token, uint256 totalAmount, Plan[] memory plans) external {
    TransferHelper.transferTokens(token, msg.sender, address(this), totalAmount);
    SafeERC20.safeIncreaseAllowance(IERC20(token), locker, totalAmount);
    for (uint16 i; i < plans.length; i++) {
      ILinearLock(locker).createNFT(
        plans[i].recipient,
        token,
        plans[i].amount,
        plans[i].start,
        plans[i].cliff,
        plans[i].rate
      );
    }
  }

  function batchLinearPlan(
    address locker,
    address token,
    uint256 totalAmount,
    Plan[] memory plans,
    address vestingAdmin
  ) external {
    TransferHelper.transferTokens(token, msg.sender, address(this), totalAmount);
    SafeERC20.safeIncreaseAllowance(IERC20(token), locker, totalAmount);
    for (uint16 i; i < plans.length; i++) {
      ILinearVester(locker).createNFT(
        plans[i].recipient,
        token,
        plans[i].amount,
        plans[i].start,
        plans[i].cliff,
        plans[i].rate,
        vestingAdmin
      );
    }
  }
}
