// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '../libraries/TransferHelper.sol';
import '../libraries/TimelockLibrary.sol';
import '../interfaces/IVestingPlans.sol';
import '../interfaces/ILockupPlans.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

contract ClaimCampaigns is ReentrancyGuard {
  address private donationCollector;

  enum TokenLockup {
    Unlocked,
    Locked,
    Vesting
  }

  struct ClaimLockup {
    address tokenLocker;
    uint256 rate;
    uint256 start;
    uint256 cliff;
    uint256 period;
  }

  struct Campaign {
    address manager;
    address token;
    uint256 amount;
    uint256 end;
    TokenLockup tokenLockup;
    bytes32 root;
  }

  struct Donation {
    address tokenLocker;
    uint256 amount;
    uint256 rate;
    uint256 start;
    uint256 cliff;
    uint256 period;
  }

  mapping(bytes16 => bool) public usedIds;
  mapping(bytes16 => Campaign) public campaigns;
  mapping(bytes16 => ClaimLockup) public claimLockups;

  //maps campaign id to a wallet address, which is flipped to true when claimed
  mapping(bytes16 => mapping(address => bool)) public claimed;

  // events
  event CampaignStarted(bytes16 indexed id, Campaign campaign);
  event ClaimLockupCreated(bytes16 indexed id, ClaimLockup claimLockup);
  event CampaignCancelled(bytes16 indexed id);
  event TokensClaimed(bytes16 indexed id, address indexed claimer, uint256 amountClaimed, uint256 amountRemaining);

  constructor(address _donationCollector) {
    donationCollector = _donationCollector;
  }

  function donationUpdates(address newCollector) external {
    require(msg.sender == donationCollector);
    donationCollector = newCollector;
  }

  function createUnlockedCampaign(
    bytes16 id,
    Campaign memory campaign,
    Donation memory donation
  ) external nonReentrant {
    require(!usedIds[id], 'in use');
    usedIds[id] = true;
    require(campaign.token != address(0), '0_address');
    require(campaign.manager != address(0), '0_manager');
    require(campaign.amount > 0, '0_amount');
    require(campaign.end > block.timestamp, 'end error');
    require(campaign.tokenLockup == TokenLockup.Unlocked, 'locked');
    TransferHelper.transferTokens(campaign.token, msg.sender, address(this), campaign.amount + donation.amount);
    if (donation.amount > 0) {
      if (donation.start > 0) {
        SafeERC20.safeIncreaseAllowance(IERC20(campaign.token), donation.tokenLocker, donation.amount);
        ILockupPlans(donation.tokenLocker).createPlan(
          donationCollector,
          campaign.token,
          donation.amount,
          donation.start,
          donation.cliff,
          donation.rate,
          donation.period
        );
      } else {
        TransferHelper.withdrawTokens(campaign.token, donationCollector, donation.amount);
      }
    }
    campaigns[id] = campaign;
    emit CampaignStarted(id, campaign);
  }

  function createLockedCampaign(
    bytes16 id,
    Campaign memory campaign,
    ClaimLockup memory claimLockup,
    Donation memory donation
  ) external nonReentrant {
    require(!usedIds[id], 'in use');
    usedIds[id] = true;
    require(campaign.token != address(0), '0_address');
    require(campaign.manager != address(0), '0_manager');
    require(campaign.amount > 0, '0_amount');
    require(campaign.end > block.timestamp, 'end error');
    require(campaign.tokenLockup != TokenLockup.Unlocked, '!locked');
    require(claimLockup.tokenLocker != address(0), 'invalide locker');
    TransferHelper.transferTokens(campaign.token, msg.sender, address(this), campaign.amount + donation.amount);
    if (donation.amount > 0) {
      if (donation.start > 0) {
        SafeERC20.safeIncreaseAllowance(IERC20(campaign.token), donation.tokenLocker, donation.amount);
        ILockupPlans(donation.tokenLocker).createPlan(
          donationCollector,
          campaign.token,
          donation.amount,
          donation.start,
          donation.cliff,
          donation.rate,
          donation.period
        );
      } else {
        TransferHelper.withdrawTokens(campaign.token, donationCollector, donation.amount);
      }
    }
    (, bool valid) = TimelockLibrary.validateEnd(
      claimLockup.start,
      claimLockup.cliff,
      campaign.amount,
      claimLockup.rate,
      claimLockup.period
    );
    require(valid);
    claimLockups[id] = claimLockup;
    SafeERC20.safeIncreaseAllowance(IERC20(campaign.token), claimLockup.tokenLocker, campaign.amount);
    campaigns[id] = campaign;
    emit ClaimLockupCreated(id, claimLockup);
    emit CampaignStarted(id, campaign);
  }

  function claimTokens(bytes16 campaignId, bytes32[] memory proof, uint256 claimAmount) external nonReentrant {
    require(!claimed[campaignId][msg.sender], 'already claimed');
    Campaign memory campaign = campaigns[campaignId];
    require(campaign.end > block.timestamp, 'campaign ended');
    require(verify(campaign.root, proof, msg.sender, claimAmount), '!eligible');
    require(campaign.amount >= claimAmount, 'campaign unfunded');
    claimed[campaignId][msg.sender] = true;
    campaigns[campaignId].amount -= claimAmount;
    if (campaigns[campaignId].amount == 0) {
      delete campaigns[campaignId];
    }
    if (campaign.tokenLockup == TokenLockup.Unlocked) {
      TransferHelper.withdrawTokens(campaign.token, msg.sender, claimAmount);
    } else {
      ClaimLockup memory c = claimLockups[campaignId];
      if (campaign.tokenLockup == TokenLockup.Locked) {
        ILockupPlans(c.tokenLocker).createPlan(
          msg.sender,
          campaign.token,
          claimAmount,
          c.start,
          c.cliff,
          c.rate,
          c.period
        );
      } else {
        IVestingPlans(c.tokenLocker).createPlan(
          msg.sender,
          campaign.token,
          claimAmount,
          c.start,
          c.cliff,
          c.rate,
          c.period,
          campaign.manager,
          false
        );
      }
    }
    emit TokensClaimed(campaignId, msg.sender, claimAmount, campaigns[campaignId].amount);
  }

  function cancelCampaign(bytes16 campaignId) external nonReentrant {
    Campaign memory campaign = campaigns[campaignId];
    require(campaign.manager == msg.sender, '!manager');
    delete campaigns[campaignId];
    delete claimLockups[campaignId];
    TransferHelper.withdrawTokens(campaign.token, msg.sender, campaign.amount);
    emit CampaignCancelled(campaignId);
  }

  function verify(bytes32 root, bytes32[] memory proof, address claimer, uint256 amount) public pure returns (bool) {
    bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(claimer, amount))));
    require(MerkleProof.verify(proof, root, leaf), 'Invalid proof');
    return true;
  }
}
