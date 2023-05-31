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
  address public lockedPlans;
  address public vestingPlans;
  address public linearLocker;
  address public linearVester;

  struct Plan {
    address recipient;
    uint256 amount;
    uint256 start;
    uint256 cliff;
    uint256 rate;
  }

  constructor(address _lockedPlans, address _vestingPlans, address _linearLocker, address _linearVester) {
    lockedPlans = _lockedPlans;
    vestingPlans = _vestingPlans;
    linearLocker = _linearLocker;
    linearVester = _linearVester;
  }

  function batchLockingPlans(address token, uint256 totalAmount, Plan[] memory plans, uint256 period) external {
    TransferHelper.transferTokens(token, msg.sender, address(this), totalAmount);
    SafeERC20.safeIncreaseAllowance(IERC20(token), lockedPlans, totalAmount);
    for (uint16 i; i < plans.length; i++) {
      ILockedTokenPlans(lockedPlans).createPlan(
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
    address token,
    uint256 totalAmount,
    Plan[] memory plans,
    uint256 period,
    address vestingAdmin
  ) external {
    TransferHelper.transferTokens(token, msg.sender, address(this), totalAmount);
    SafeERC20.safeIncreaseAllowance(IERC20(token), vestingPlans, totalAmount);
    for (uint16 i; i < plans.length; i++) {
      IVestingTokenPlans(vestingPlans).createPlan(
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

  function batchLinearPlan(address token, uint256 totalAmount, Plan[] memory plans) external {
    TransferHelper.transferTokens(token, msg.sender, address(this), totalAmount);
    SafeERC20.safeIncreaseAllowance(IERC20(token), linearLocker, totalAmount);
    for (uint16 i; i < plans.length; i++) {
      ILinearLock(linearLocker).createNFT(
        plans[i].recipient,
        token,
        plans[i].amount,
        plans[i].start,
        plans[i].cliff,
        plans[i].rate
      );
    }
  }

  function batchLinearPlan(address token, uint256 totalAmount, Plan[] memory plans, address vestingAdmin) external {
    TransferHelper.transferTokens(token, msg.sender, address(this), totalAmount);
    SafeERC20.safeIncreaseAllowance(IERC20(token), linearVester, totalAmount);
    for (uint16 i; i < plans.length; i++) {
      ILinearVester(linearVester).createNFT(
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
