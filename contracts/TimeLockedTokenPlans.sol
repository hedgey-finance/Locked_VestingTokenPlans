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

  function segmentPlan(address holder, uint256 planId, uint256 segmentAmount) internal {
    require(ownerOf(plandId) == holder, '!holder');
    Plan memory plan = plans[planId];
    require(plan.amount % segmentAmount == 0, 'invalid segment');
    uint256 end = TimelockLibrary.endDate(plan.start, plan.amount, plan.rate, plan.period);
    //it creates a new NFT whereby the segment amount is carved off and placed into a new NFT
    _planIds.increment();
    uint256 newPlanId = _planIds.current();
    // update the current plan with amended details;
    // first amount now is amount less segment
    uint256 planAmount = plan.amount - segmentAmount;
    plans[planId].amount = planAmount;
    uint256 planRate = plan.rate / (planAmount / plan.amount  ); 
    plans[planId].rate = planRate;
    uint256 segmentRate = plan.rate / (planAmount / segmentAmount);
    uint256 planEndCheck = TimelockLibrary.endDate(plan.start, planAmount, planRate, plan.period);
    uint256 segmentEndCheck = TimelockLibrary.endDate(plan.start, segmentAmount, segmentRate, plan.period);
    require(end == planEndCheck, '!planEnd');
    require(end == segmentEndCheck, '!segmentEnd');
    require(segmentRate + planRate == plan.rate, "rate error");
    plans[newPlanId] = Plan(plan.token, segmentAmount, plan.start, plan.cliff, segmentRate, plan.period);
    emit PlanCreated(newPlanId, holder, plan.token, segmentAmount, plan.start, plan.cliff, end, segmentRate, plan.period);
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
