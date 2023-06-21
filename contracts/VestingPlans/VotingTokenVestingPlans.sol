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
import '../sharedContracts/VestingStorage.sol';

contract VotingTokenVestingPlans is ERC721Enumerable, VestingStorage, ReentrancyGuard, URIAdmin {
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
    uint256 period,
    address vestingAdmin,
    bool adminTransferOBO
  ) external nonReentrant returns (uint256 newPlanId) {
    require(recipient != address(0), '0_recipient');
    require(token != address(0), '0_token');
    (uint256 end, bool valid) = TimelockLibrary.validateEnd(start, cliff, amount, rate, period);
    require(valid);
    _planIds.increment();
    newPlanId = _planIds.current();
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

  function revokePlans(uint256[] memory planIds) external nonReentrant {
    for (uint256 i; i < planIds.length; i++) {
      _revokePlan(msg.sender, planIds[i]);
    }
  }

  function changeVestingPlanAdmin(uint256 planId, address newVestingAdmin) external {
    Plan storage plan = plans[planId];
    require(msg.sender == plan.vestingAdmin, '!vestingAdmin');
    require(ownerOf(planId) != newVestingAdmin, '!planOwner');
    plan.vestingAdmin = newVestingAdmin;
    emit VestingPlanAdminChanged(planId, newVestingAdmin);
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
    address vault = votingVaults[planId];
    if (vault == address(0)) {
      TransferHelper.withdrawTokens(plan.token, vestingAdmin, remainder);
      TransferHelper.withdrawTokens(plan.token, holder, balance);
    } else {
      delete votingVaults[planId];
      VotingVault(vault).withdrawTokens(vestingAdmin, remainder);
      VotingVault(vault).withdrawTokens(holder, balance);
    }
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

  /****EXTERNAL VOTING FUNCTIONS*********************************************************************************************************************************************/

  function setupVoting(uint256 planId) external nonReentrant returns (address votingVault) {
    votingVault = _setupVoting(msg.sender, planId);
  }

  function delegate(uint256 planId, address delegatee) external nonReentrant {
    _delegate(msg.sender, planId, delegatee);
  }

  function delegatePlans(uint256[] memory planIds, address[] memory delegatees) external nonReentrant {
    require(planIds.length == delegatees.length, 'array error');
    for (uint256 i; i < planIds.length; i++) {
      _delegate(msg.sender, planIds[i], delegatees[i]);
    }
  }

  function delegateAll(address token, address delegatee) external nonReentrant {
    uint256 balance = balanceOf(msg.sender);
    for (uint256 i; i < balance; i++) {
      uint256 planId = tokenOfOwnerByIndex(msg.sender, i);
      if (plans[planId].token == token) _delegate(msg.sender, planId, delegatee);
    }
  }

  /****INTERNAL VOTING FUNCTIONS*********************************************************************************************************************************************/

  function _setupVoting(address holder, uint256 planId) internal returns (address) {
    require(ownerOf(planId) == holder, '!owner');
    require(votingVaults[planId] == address(0), 'exists');
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

  /****NFT FRANSFER SPECIAL OVERRIDE FUNCTIONS*********************************************************************************************************************************************/

  function transferFrom(address from, address to, uint256 tokenId) public override(IERC721, ERC721) {
    require(plans[tokenId].adminTransferOBO, '!transferrable');
    require(to != plans[tokenId].vestingAdmin, '!transfer to admin');
    require(msg.sender == plans[tokenId].vestingAdmin, '!vestingAdmin');
    _transfer(from, to, tokenId);
    emit PlanTransferredByVestingAdmin(tokenId, from, to);
  }

  function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal override {
    revert('!transferrable');
  }
}
