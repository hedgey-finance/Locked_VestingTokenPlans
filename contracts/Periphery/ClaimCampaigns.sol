// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '../libraries/TransferHelper.sol';
import '../libraries/TimelockLibrary.sol';
import '../interfaces/IVestingPlans.sol';
import '../interfaces/ILockupPlans.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

contract ClaimCampaigns is ReentrancyGuard {

  address private feeCollector;
  address internal feeLocker;
  uint256 internal feeLockupTime;
  bool internal feeLocked;

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

  mapping(bytes16 => bool) public usedIds;
  mapping(bytes16 => Campaign) public campaigns;
  mapping(bytes16 => ClaimLockup) public claimLockups;

  //maps campaign id to a wallet address, which is flipped to true when claimed
  mapping(bytes16 => mapping(address => bool)) public claimed;

  // events
  event CampaignStarted(bytes16 indexed id, Campaign campaign);
  event ClaimLockupCreated(bytes16 indexed id, ClaimLockup claimLockup);
  event CampaignCancelled(bytes16 indexed id);
  event TokensClaimed(bytes16 indexed id, address indexed claimer, uint256 amount);

  constructor(address _feeCollector, address _feeLocker, uint256 _feeLockupTime, bool _feeLocked) {
    feeCollector = _feeCollector;
    feeLocker = _feeLocker;
    feeLockupTime = _feeLockupTime;
    feeLocked = _feeLocked;
  }

  function feeCollectionUpdates(address _feeCollector, address _feeLocker, uint256 _feeLockupTime, bool _feeLocked) external {
    require(msg.sender == feeCollector);
    feeCollector = _feeCollector;
    feeLocker = _feeLocker;
    feeLockupTime = _feeLockupTime;
    feeLocked = _feeLocked;
  }

  function createCampaign(bytes16 id, Campaign memory campaign, ClaimLockup memory claimLockup, uint256 fee) external nonReentrant {
    require(!usedIds[id], 'in use');
    usedIds[id] = true;
    require(campaign.token != address(0), "0address");
    require(campaign.manager != address(0), "0manager");
    require(campaign.amount > 0, "0amount");
    require(campaign.end > block.timestamp);
    TransferHelper.transferTokens(campaign.token, msg.sender, address(this), campaign.amount + fee);
    if (fee > 0) {
      if (feeLocked) {
        SafeERC20.safeIncreaseAllowance(IERC20(campaign.token), feeLocker, fee);
      uint256 rate = fee / feeLockupTime;
      ILockupPlans(feeLocker).createPlan(feeCollector, campaign.token, fee, block.timestamp, 0, rate, 1);
      } else {
        TransferHelper.withdrawTokens(campaign.token, feeCollector, fee);
      }
    }
    if (campaign.tokenLockup != TokenLockup.Unlocked) {
      require(claimLockup.tokenLocker != address(0), "invalide locker");
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
      emit ClaimLockupCreated(id, claimLockup);
    }
    campaigns[id] = campaign;
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
      delete claimLockups[campaignId];
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
    emit TokensClaimed(campaignId, msg.sender, claimAmount);
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
