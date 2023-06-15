// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '../ERC721Delegate/ERC721Delegate.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '../libraries/TransferHelper.sol';
import '../libraries/TimelockLibrary.sol';
import '../sharedContracts/URIAdmin.sol';
import '../sharedContracts/LockupStorage.sol';

contract TokenLockupPlans is ERC721Delegate, LockupStorage, ReentrancyGuard, URIAdmin {
  using Counters for Counters.Counter;
  Counters.Counter private _planIds;

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    uriAdmin = msg.sender;
  }

  function _baseURI() internal view override returns (string memory) {
    return baseURI;
  }

  /****CORE EXTERNAL FUNCTIONS*********************************************************************************************************************************************/

  function createPlan(
    address recipient,
    address token,
    uint256 amount,
    uint256 start,
    uint256 cliff,
    uint256 rate,
    uint256 period
  ) external nonReentrant returns (uint256 newPlanId) {
    require(recipient != address(0), '01');
    require(token != address(0), '02');
    (uint256 end, bool valid) = TimelockLibrary.validateEnd(start, cliff, amount, rate, period);
    require(valid);
    _planIds.increment();
    newPlanId = _planIds.current();
    TransferHelper.transferTokens(token, msg.sender, address(this), amount);
    plans[newPlanId] = Plan(token, amount, start, cliff, rate, period);
    _safeMint(recipient, newPlanId);
    emit PlanCreated(newPlanId, recipient, token, amount, start, cliff, end, rate, period);
  }

  function redeemPlans(uint256[] memory planIds) external nonReentrant {
    _redeemPlans(planIds, block.timestamp);
  }

  function partialRedeemPlans(uint256[] memory planIds, uint256 redemptionTime) external nonReentrant {
    require(redemptionTime < block.timestamp, '!future redemption');
    _redeemPlans(planIds, redemptionTime);
  }

  function redeemAllPlans() external nonReentrant {
    uint256 balance = balanceOf(msg.sender);
    uint256[] memory planIds = new uint256[](balance);
    for (uint256 i; i < balance; i++) {
      uint256 planId = _tokenOfOwnerByIndex(msg.sender, i);
      planIds[i] = planId;
    }
    _redeemPlans(planIds, block.timestamp);
  }

  function segmentPlan(uint256 planId, uint256[] memory segmentAmounts) external nonReentrant returns (uint256[] memory newPlanIds) {
    newPlanIds = new uint256[](segmentAmounts.length);
    for (uint256 i; i < segmentAmounts.length; i++) {
      uint256 newPlanId = _segmentPlan(msg.sender, planId, segmentAmounts[i]);
      newPlanIds[i] = newPlanId;
    }
  }

  function segmentAndDelegatePlans(
    uint256 planId,
    uint256[] memory segmentAmounts,
    address[] memory delegatees
  ) external nonReentrant returns (uint256[] memory newPlanIds) {
    require(segmentAmounts.length == delegatees.length, '!length');
    newPlanIds = new uint256[](segmentAmounts.length);
    for (uint256 i; i < segmentAmounts.length; i++) {
      uint256 newPlanId = _segmentPlan(msg.sender, planId, segmentAmounts[i]);
      _delegateToken(delegatees[i], newPlanId);
      newPlanIds[i] = newPlanId;
    }
  }

  function combinePlans(uint256 planId0, uint256 planId1) external nonReentrant returns (uint256 survivingPlanId) {
    survivingPlanId = _combinePlans(msg.sender, planId0, planId1);
  }

  function redeemAndTransfer(uint256 planId, address to) external virtual nonReentrant {
    (uint256 balance, uint256 remainder, uint256 latestUnlock) = planBalanceOf(
      planId,
      block.timestamp,
      block.timestamp
    );
    if (balance > 0) _redeemPlan(msg.sender, planId, balance, remainder, latestUnlock);
    if (remainder > 0) _transfer(msg.sender, to, planId);
  }

  /****CORE INTERNAL FUNCTIONS*********************************************************************************************************************************************/

  function _redeemPlans(uint256[] memory planIds, uint256 redemptionTime) internal {
    for (uint256 i; i < planIds.length; i++) {
      (uint256 balance, uint256 remainder, uint256 latestUnlock) = planBalanceOf(
        planIds[i],
        block.timestamp,
        redemptionTime
      );
      if (balance > 0) _redeemPlan(msg.sender, planIds[i], balance, remainder, latestUnlock);
    }
  }

  function _redeemPlan(
    address holder,
    uint256 planId,
    uint256 balance,
    uint256 remainder,
    uint256 latestUnlock
  ) internal {
    require(ownerOf(planId) == holder, '!holder');
    Plan memory plan = plans[planId];
    if (remainder == 0) {
      delete plans[planId];
      _burn(planId);
    } else {
      plans[planId].amount = remainder;
      plans[planId].start = latestUnlock;
    }
    TransferHelper.withdrawTokens(plan.token, holder, balance);
    emit PlanTokensUnlocked(planId, balance, remainder, latestUnlock);
  }

  function _segmentPlan(address holder, uint256 planId, uint256 segmentAmount) internal returns (uint256 newPlanId) {
    require(ownerOf(planId) == holder, '!holder');
    Plan memory plan = plans[planId];
    require(segmentAmount < plan.amount, 'amount error');
    uint256 end = TimelockLibrary.endDate(plan.start, plan.amount, plan.rate, plan.period);
    _planIds.increment();
    newPlanId = _planIds.current();
    _safeMint(holder, newPlanId);
    uint256 planAmount = plan.amount - segmentAmount;
    plans[planId].amount = planAmount;
    uint256 planRate = (plan.rate * ((planAmount * (10 ** 18)) / plan.amount)) / (10 ** 18);
    plans[planId].rate = planRate;
    uint256 segmentRate = plan.rate - planRate;
    (uint256 planEnd, bool validPlan) = TimelockLibrary.validateEnd(plan.start, plan.cliff, planAmount, planRate, plan.period);
    (uint256 segmentEnd, bool validSegment) = TimelockLibrary.validateEnd(plan.start, plan.cliff, segmentAmount, segmentRate, plan.period);
    require(validPlan && validSegment, 'invalid new plans');
    uint256 endCheck = segmentOriginalEnd[planId] == 0 ? end : segmentOriginalEnd[planId];
    require(planEnd >= endCheck, 'plan end error');
    require(segmentEnd >= endCheck, 'segmentEnd error');
    plans[newPlanId] = Plan(plan.token, segmentAmount, plan.start, plan.cliff, segmentRate, plan.period);
    if (segmentOriginalEnd[planId] == 0) {
      segmentOriginalEnd[planId] = end;
      segmentOriginalEnd[newPlanId] = end;
    } else {
      segmentOriginalEnd[newPlanId] = segmentOriginalEnd[planId];
    }
    emit PlanSegmented(
      planId,
      newPlanId,
      planAmount,
      planRate,
      segmentAmount,
      segmentRate,
      plan.start,
      plan.cliff,
      plan.period,
      planEnd
    );
  }

  function _combinePlans(address holder, uint256 planId0, uint256 planId1) internal returns (uint256 survivingPlan) {
    require(ownerOf(planId0) == holder, '!holder');
    require(ownerOf(planId1) == holder, '!holder');
    Plan memory plan0 = plans[planId0];
    Plan memory plan1 = plans[planId1];
    require(plan0.token == plan1.token, 'token error');
    require(plan0.start == plan1.start, 'start error');
    require(plan0.cliff == plan1.cliff, 'cliff error');
    require(plan0.period == plan1.period, 'period error');
    uint256 plan0End = TimelockLibrary.endDate(plan0.start, plan0.amount, plan0.rate, plan0.period);
    uint256 plan1End = TimelockLibrary.endDate(plan1.start, plan1.amount, plan1.rate, plan1.period);
    // either they have the same end date, or if they dont then they should have the same original end date if they were segmented
    require(plan0End == plan1End || segmentOriginalEnd[planId0] == segmentOriginalEnd[planId1], 'end error');
    // add em together and delete plan 1
    plans[planId0].amount += plans[planId1].amount;
    plans[planId0].rate += plans[planId1].rate;
    uint256 end = TimelockLibrary.endDate(plan0.start, plans[planId0].amount, plans[planId0].rate, plan0.period);
    if (end < plan0End) {
      console.log('end was lower, have to check original');
      require(end == segmentOriginalEnd[planId0] || end == segmentOriginalEnd[planId1], 'original end error');
    }
    delete plans[planId1];
    _burn(planId1);
    survivingPlan = planId0;
    emit PlansCombined(
      planId0,
      planId1,
      survivingPlan,
      plans[planId0].amount,
      plans[planId0].rate,
      plan0.start,
      plan0.cliff,
      plan0.period,
      end
    );
  }

  /****VOTING FUNCTIONS*********************************************************************************************************************************************/

  function delegate(uint256 planId, address delegatee) external nonReentrant {
      _delegateToken(delegatee, planId);
  }

  function delegateAll(address delegatee) external nonReentrant {
    uint256 balance = balanceOf(msg.sender);
    for (uint256 i; i < balance; i++) {
      uint256 planId = _tokenOfOwnerByIndex(msg.sender, i);
      _delegateToken(delegatee, planId);
    }
  }

  function lockedBalances(address holder, address token) external view returns (uint256 lockedBalance) {
    uint256 holdersBalance = balanceOf(holder);
    for (uint256 i; i < holdersBalance; i++) {
      uint256 planId = _tokenOfOwnerByIndex(holder, i);
      Plan memory plan = plans[planId];
      if (token == plan.token) {
        lockedBalance += plan.amount;
      }
    }
  }

  function delegatedBalances(address delegate, address token) external view returns (uint256 delegatedBalance) {
    uint256 delegateBalance = balanceOfDelegate(delegate);
    for (uint256 i; i < delegateBalance; i++) {
      uint256 planId = tokenOfDelegateByIndex(delegate, i);
      Plan memory plan = plans[planId];
      if (token == plan.token) {
        delegatedBalance += plan.amount;
      }
    }
  }
}
