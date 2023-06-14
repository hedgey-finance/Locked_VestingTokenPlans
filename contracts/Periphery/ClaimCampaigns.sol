// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '../libraries/TransferHelper.sol';
import '../libraries/TimelockLibrary.sol';
import '../interfaces/IVestingPlans.sol';
import '../interfaces/ILockupPlans.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

contract ClaimCampaigns is ReentrancyGuard {
  uint256 private _campaignIds;

  address private feeCollector;
  address internal feeLocker;

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

  mapping(uint256 => Campaign) public campaigns;
  mapping(uint256 => ClaimLockup) public claimLockups;

  //maps campaign id to a wallet address, which is flipped to true when claimed
  mapping(uint256 => mapping(address => bool)) public claimed;

  // events
  event CampaignStarted(uint256 indexed id, Campaign campaign);
  event ClaimLockupCreated(uint256 indexed id, ClaimLockup claimLockup);

  constructor(address _feeCollector, address _feeLocker) {
    feeCollector = _feeCollector;
    feeLocker = _feeLocker;
  }

  function createCampaign(Campaign memory campaign, ClaimLockup memory claimLockup, uint256 fee) external nonReentrant {
    require(campaign.token != address(0));
    require(campaign.manager != address(0));
    require(campaign.amount > 0);
    require(campaign.end > block.timestamp);
    _campaignIds++;
    TransferHelper.transferTokens(campaign.token, msg.sender, address(this), campaign.amount);
    if (fee > 0) {
      SafeERC20.safeIncreaseAllowance(IERC20(campaign.token), feeLocker, fee);
      ILockupPlans(feeLocker).createPlan(feeCollector, campaign.token, fee, block.timestamp, 0, 1, 1);
    }
    if (campaign.tokenLockup != TokenLockup.Unlocked) {
      require(claimLockup.tokenLocker != address(0));
      (uint256 end, bool valid) = TimelockLibrary.validateEnd(
        claimLockup.start,
        claimLockup.cliff,
        campaign.amount,
        claimLockup.rate,
        claimLockup.period
      );
      require(valid);
      claimLockups[_campaignIds] = claimLockup;
      SafeERC20.safeIncreaseAllowance(IERC20(campaign.token), claimLockup.tokenLocker, campaign.amount);
      emit ClaimLockupCreated(_campaignIds, claimLockup);
    }
    campaigns[_campaignIds] = campaign;
    emit CampaignStarted(_campaignIds, campaign);
  }

  function claimTokens(uint256 campaignId, bytes32[] memory proof, uint256 claimAmount) external nonReentrant {
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
  }

  function cancelCampaign(uint256 campaignId) external nonReentrant {
    Campaign memory campaign = campaigns[campaignId];
    require(campaign.manager == msg.sender, '!manager');
    delete campaigns[campaignId];
    delete claimLockups[campaignId];
    TransferHelper.withdrawTokens(campaign.token, msg.sender, campaign.amount);
  }

  function verify(bytes32 root, bytes32[] memory proof, address claimer, uint256 amount) public pure returns (bool) {
    bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(claimer, amount))));
    require(MerkleProof.verify(proof, root, leaf), 'Invalid proof');
    return true;
  }

  function currentCampaignId() public view returns (uint256) {
    return _campaignIds;
  }
}
