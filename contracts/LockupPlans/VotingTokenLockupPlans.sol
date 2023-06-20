// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '../libraries/TransferHelper.sol';
import '../libraries/TimelockLibrary.sol';
import '../sharedContracts/VotingVault.sol';
import '../sharedContracts/URIAdmin.sol';
import '../sharedContracts/LockupStorage.sol';

import 'hardhat/console.sol';

contract VotingTokenLockupPlans is ERC721Enumerable, LockupStorage, ReentrancyGuard, URIAdmin {
  using Counters for Counters.Counter;
  Counters.Counter private _planIds;

  mapping(uint256 => address) public votingVaults;

  event VotingVaultCreated(uint256 indexed id, address vaultAddress);

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
    require(recipient != address(0), '0_recipient');
    require(token != address(0), '0_token');
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
    require(redemptionTime < block.timestamp, '!future');
    _redeemPlans(planIds, redemptionTime);
  }

  function redeemAllPlans() external nonReentrant {
    uint256 balance = balanceOf(msg.sender);
    uint256[] memory planIds = new uint256[](balance);
    for (uint256 i; i < balance; i++) {
      uint256 planId = tokenOfOwnerByIndex(msg.sender, i);
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
      _delegate(msg.sender, newPlanId, delegatees[i]);
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
    require(ownerOf(planId) == holder, '!owner');
    Plan memory plan = plans[planId];
    address vault = votingVaults[planId];
    if (remainder == 0) {
      delete plans[planId];
      delete votingVaults[planId];
      _burn(planId);
    } else {
      plans[planId].amount = remainder;
      plans[planId].start = latestUnlock;
    }
    if (vault == address(0)) {
      TransferHelper.withdrawTokens(plan.token, holder, balance);
    } else {
      VotingVault(vault).withdrawTokens(holder, balance);
    }
    emit PlanRedeemed(planId, balance, remainder, latestUnlock);
  }

  function _segmentPlan(address holder, uint256 planId, uint256 segmentAmount) internal returns (uint256 newPlanId) {
    require(ownerOf(planId) == holder, '!owner');
    Plan memory plan = plans[planId];
    require(segmentAmount < plan.amount, 'amount error');
    require(segmentAmount > 0, '0_segment');
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
    if (votingVaults[planId] != address(0)) {
      VotingVault(votingVaults[planId]).withdrawTokens(address(this), segmentAmount);
      _setupVoting(holder, newPlanId);
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
    require(ownerOf(planId0) == holder, '!owner');
    require(ownerOf(planId1) == holder, '!owner');
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
    address vault0 = votingVaults[planId0];
    address vault1 = votingVaults[planId1];
    survivingPlan = planId0;
    if (vault0 != address(0)) {
      plans[planId0].amount += plans[planId1].amount;
      plans[planId0].rate += plans[planId1].rate;
      uint256 end = TimelockLibrary.endDate(plan0.start, plans[planId0].amount, plans[planId0].rate, plan0.period);
      if (end < plan0End) {
        require(end == segmentOriginalEnd[planId0] || end == segmentOriginalEnd[planId1], 'original end error');
      }
      if (vault1 != address(0)) {
        VotingVault(vault1).withdrawTokens(vault0, plan1.amount);
      } else {
        TransferHelper.withdrawTokens(plan0.token, vault0, plan1.amount);
      }
      delete plans[planId1];
      _burn(planId1);
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
    } else if (vault1 != address(0)) {
      plans[planId1].amount += plans[planId0].amount;
      plans[planId1].rate += plans[planId0].rate;
      uint256 end = TimelockLibrary.endDate(plan1.start, plans[planId1].amount, plans[planId1].rate, plan1.period);
      if (end < plan1End) {
        require(end == segmentOriginalEnd[planId0] || end == segmentOriginalEnd[planId1], 'original end error');
      }
      TransferHelper.withdrawTokens(plan0.token, vault1, plan0.amount);
      survivingPlan = planId1;
      delete plans[planId0];
      _burn(planId0);
      emit PlansCombined(
        planId0,
        planId1,
        survivingPlan,
        plans[planId1].amount,
        plans[planId1].rate,
        plan1.start,
        plan1.cliff,
        plan1.period,
        end
      );
    } else {
      plans[planId0].amount += plans[planId1].amount;
      plans[planId0].rate += plans[planId1].rate;
      uint256 end = TimelockLibrary.endDate(plan0.start, plans[planId0].amount, plans[planId0].rate, plan0.period);
      if (end < plan0End) {
        require(end == segmentOriginalEnd[planId0] || end == segmentOriginalEnd[planId1], 'original end error');
      }
      delete plans[planId1];
      _burn(planId1);
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
  }

  /****EXTERNAL VOTING FUNCTIONS*********************************************************************************************************************************************/

  function setupVoting(uint256 planId) external nonReentrant returns (address votingVault) {
    votingVault = _setupVoting(msg.sender, planId);
  }

  function delegate(uint256 planId, address delegatee) external nonReentrant {
    _delegate(msg.sender, planId, delegatee);
  }

  function delegatePlans(uint256[] memory planIds, address[] memory delegatees) external nonReentrant {
    require(planIds.length == delegatees.length, 'length error');
    for (uint256 i; i < planIds.length; i++) {
      _delegate(msg.sender, planIds[i], delegatees[i]);
    }
  } 

  function delegateAll(address delegatee) external nonReentrant {
    uint256 balance = balanceOf(msg.sender);
    for (uint256 i; i < balance; i++) {
      uint256 planId = tokenOfOwnerByIndex(msg.sender, i);
      _delegate(msg.sender, planId, delegatee);
    }
  }

/****INTERNAL VOTING FUNCTIONS*********************************************************************************************************************************************/ 

  function _setupVoting(address holder, uint256 planId) internal returns (address) {
    require(ownerOf(planId) == holder, '!owner');
    require(votingVaults[planId] == address(0), "exists");
    Plan memory plan = plans[planId];
    VotingVault vault = new VotingVault(plan.token, holder);
    votingVaults[planId] = address(vault);
    TransferHelper.withdrawTokens(plan.token, address(vault), plan.amount);
    emit VotingVaultCreated(planId, address(vault));
    return address(vault);
  }

  function _delegate(address holder, uint256 planId, address delegatee) internal {
    require(ownerOf(planId) == holder, '!owner');
    address vault = votingVaults[planId];
    if (votingVaults[planId] == address(0)) {
      vault = _setupVoting(holder, planId);
    }
    VotingVault(vault).delegateTokens(delegatee);
  }

  /****VIEW VOTING FUNCTIONS*********************************************************************************************************************************************/

  function lockedBalances(address holder, address token) external view returns (uint256 lockedBalance) {
    uint256 holdersBalance = balanceOf(holder);
    for (uint256 i; i < holdersBalance; i++) {
      uint256 planId = tokenOfOwnerByIndex(holder, i);
      Plan memory plan = plans[planId];
      if (token == plan.token) {
        lockedBalance += plan.amount;
      }
    }
  }
}
