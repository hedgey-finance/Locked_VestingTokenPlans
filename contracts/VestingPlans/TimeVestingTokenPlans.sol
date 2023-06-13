// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '../ERC721Delegate/ERC721Delegate.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '../libraries/TransferHelper.sol';
import '../libraries/TimelockLibrary.sol';
import '../sharedContracts/URIAdmin.sol';
import '../sharedContracts/VestingStorage.sol';

contract TimeVestingTokenPlans is ERC721Delegate, VestingStorage, ReentrancyGuard, URIAdmin {
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
    uint256 period,
    address vestingAdmin,
    bool adminTransferOBO
  ) external nonReentrant {
    require(recipient != address(0), '01');
    require(token != address(0), '02');
    (uint256 end, bool valid) = TimelockLibrary.validateEnd(start, cliff, amount, rate, period);
    require(valid);
    _planIds.increment();
    uint256 newPlanId = _planIds.current();
    TransferHelper.transferTokens(token, msg.sender, address(this), amount);
    plans[newPlanId] = Plan(token, amount, start, cliff, rate, period, vestingAdmin, adminTransferOBO);
    _safeMint(recipient, newPlanId);
    emit PlanCreated(
      newPlanId,
      recipient,
      token,
      amount,
      start,
      cliff,
      end,
      rate,
      period,
      vestingAdmin,
      adminTransferOBO
    );
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

  function revokePlans(uint256[] memory planIds) external nonReentrant {
    for (uint256 i; i < planIds.length; i++) {
      _revokePlan(msg.sender, planIds[i]);
    }
  }

  /****CORE INTERNAL FUNCTIONS*********************************************************************************************************************************************/

  function _revokePlan(address vestingAdmin, uint256 planId) internal {
    Plan memory plan = plans[planId];
    require(vestingAdmin == plan.vestingAdmin, '!vestingAdmin');
    (uint256 balance, uint256 remainder, ) = planBalanceOf(planId, block.timestamp, block.timestamp);
    require(remainder > 0, '!Remainder');
    address holder = ownerOf(planId);
    delete plans[planId];
    _burn(planId);
    TransferHelper.withdrawTokens(plan.token, vestingAdmin, remainder);
    TransferHelper.withdrawTokens(plan.token, holder, balance);
    emit PlanRevoked(planId, balance, remainder);
  }

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

  /****VOTING FUNCTIONS*********************************************************************************************************************************************/

  function delegateTokens(address delegate, uint256[] memory planIds) external {
    for (uint256 i; i < planIds.length; i++) {
      _delegateToken(delegate, planIds[i]);
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

  /****NFT FRANSFER SPECIAL OVERRIDE FUNCTIONS*********************************************************************************************************************************************/

  function transferFrom(address from, address to, uint256 tokenId) public override(IERC721, ERC721) {
    require(plans[tokenId].adminTransferOBO, 'not transferable by vesting admin');
    require(msg.sender == plans[tokenId].vestingAdmin, 'not vesting Admin');
    _transfer(from, to, tokenId);
    emit PlanTransferredByVestingAdmin(tokenId, from, to);
  }

  function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal override {
    revert('Not transferrable');
  }
}
