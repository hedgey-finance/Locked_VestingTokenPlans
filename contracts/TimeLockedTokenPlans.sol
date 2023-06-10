// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import './ERC721Delegate/ERC721Delegate.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import './libraries/TransferHelper.sol';
import './libraries/TimelockLibrary.sol';
import './sharedContracts/URIAdmin.sol';
import './sharedContracts/LockedStorage.sol';

import 'hardhat/console.sol';

contract TimeLockedTokenPlans is ERC721Delegate, LockedStorage, ReentrancyGuard, URIAdmin {
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
  ) external nonReentrant {
    require(recipient != address(0), '01');
    require(token != address(0), '02');
    require(amount > 0, '03');
    require(rate > 0, '04');
    require(rate <= amount, '05');
    _planIds.increment();
    uint256 newPlanId = _planIds.current();
    uint256 end = TimelockLibrary.endDate(start, amount, rate, period);
    require(cliff <= end, 'SV12');
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

  function segmentPlan(uint256 planId, uint256 segmentAmount) external nonReentrant {
    _segmentPlan(msg.sender, planId, segmentAmount);
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
    if (balance == plan.amount) {
      delete plans[planId];
      _burn(planId);
    } else {
      plans[planId].amount = remainder;
      plans[planId].start = latestUnlock;
    }
    TransferHelper.withdrawTokens(plan.token, holder, balance);
    emit PlanTokensUnlocked(planId, balance, remainder, latestUnlock);
  }

  function _segmentPlan(address holder, uint256 planId, uint256 segmentAmount) internal {
    require(ownerOf(planId) == holder, '!holder');
    Plan memory plan = plans[planId];
    uint256 end = TimelockLibrary.endDate(plan.start, plan.amount, plan.rate, plan.period);
    _planIds.increment();
    uint256 newPlanId = _planIds.current();
    uint256 planAmount = plan.amount - segmentAmount;
    console.log('plan amount is set to:', planAmount);
    plans[planId].amount = planAmount;
    //uint256 planRate = (plan.rate / ((plan.amount) / planAmount));
    uint256 planRate = plan.rate * ((planAmount * (10 ** 18)) / plan.amount) / (10 ** 18);
    console.log('original plan rate is: ', plan.rate);
    console.log('planRate is now set to:', planRate);
    plans[planId].rate = planRate;
    uint256 segmentRate = plan.rate - planRate;
    console.log('segment rate is set to:', segmentRate);
    uint256 planEnd = TimelockLibrary.endDate(plan.start, planAmount, planRate, plan.period);
    uint256 segmentEnd = TimelockLibrary.endDate(plan.start, segmentAmount, segmentRate, plan.period);
    require(planEnd == segmentEnd, '!planEnd');
    require(planEnd >= end, 'plan end error');
    require(segmentEnd >= end, 'segmentEnd error');
    plans[newPlanId] = Plan(plan.token, segmentAmount, plan.start, plan.cliff, segmentRate, plan.period);
    //emit PlanCreated(newPlanId, holder, plan.token, segmentAmount, plan.start, plan.cliff, end, segmentRate, plan.period);
  }

  function _combinePlans(address holder, uint256 planId0, uint256 planId1) internal {
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
    require(plan0End == plan1End, 'end error');
    // add em together and delete plan 1
    plans[planId0].amount += plans[planId1].amount;
    plans[planId0].rate += plans[planId1].rate;
    delete plans[planId1];
    _burn(planId1);
  }

  /****VOTING FUNCTIONS*********************************************************************************************************************************************/

  function delegateTokens(address delegate, uint256[] memory planId) external {
    for (uint256 i; i < planId.length; i++) {
      _delegateToken(delegate, planId[i]);
    }
  }

  function delegateAllNFTs(address delegate) external {
    uint256 balance = balanceOf(msg.sender);
    for (uint256 i; i < balance; i++) {
      uint256 planId = _tokenOfOwnerByIndex(msg.sender, i);
      _delegateToken(delegate, planId);
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
