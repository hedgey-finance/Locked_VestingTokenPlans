// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '../libraries/TransferHelper.sol';
import '../interfaces/IVestingTokenPlans.sol';
import '../interfaces/ILockedTokenPlans.sol';
import '../interfaces/ITimeLock.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

contract ClaimCampaign is ReentrancyGuard {
  uint256 private _campaignId;

  enum TokenLockup {
    Unlocked,
    Cliff,
    Linear,
    Vesting
  }

  struct Claim {
    address tokenLocker;
    uint256 amount;
    uint256 rate;
    uint256 start;
    uint256 cliff;
    uint256 period;
  }

  struct Campaign {
    address manager;
    address token;
    uint256 amount;
    TokenLockup tokenLockup;
    bytes32 root;
  }

  mapping(uint256 => Campaign) public campaigns;
  mapping(uint256 => Claim) public claims;

  //maps campaign id to a wallet address, which is flipped to true when claimed
  mapping(uint256 => mapping(address => bool)) public claimed;

  function createCampaign(Campaign memory campaign, Claim memory claim, uint256 hedgeyTip) external nonReentrant {
    require(campaign.token != address(0));
    require(campaign.manager != address(0));
    _campaignId++;
    TransferHelper.transferTokens(campaign.token, msg.sender, address(this), campaign.amount + hedgeyTip);
    if (claim.tokenLocker != address(0))
      SafeERC20.safeIncreaseAllowance(IERC20(campaign.token), claim.tokenLocker, campaign.amount);
    campaigns[_campaignId] = campaign;
    claims[_campaignId] = claim;
    //emit event
  }

  function claimTokens(uint256 campaignId, bytes32[] memory proof, uint256 claimAmount) external nonReentrant {
    require(!claimed[campaignId][msg.sender], 'already claimed');
    Campaign memory campaign = campaigns[campaignId];
    require(verify(campaign.root, proof, msg.sender, claimAmount), '!eligible');
    require(campaign.amount >= claimAmount, 'campaign unfunded');
    Claim memory claim = claims[campaignId];
    claimed[campaignId][msg.sender] = true;
    campaigns[campaignId].amount -= claimAmount;
    if (campaigns[campaignId].amount == 0) {
      delete campaigns[campaignId];
      delete claims[campaignId];
    }
    if (campaign.tokenLockup == TokenLockup.Unlocked) {
      TransferHelper.withdrawTokens(campaign.token, msg.sender, claimAmount);
    } else if (campaign.tokenLockup == TokenLockup.Cliff) {
      ITimeLock(claim.tokenLocker).createNFT(msg.sender, claimAmount, campaign.token, claim.cliff);
    } else if (campaign.tokenLockup == TokenLockup.Linear) {
      ILockedTokenPlans(claim.tokenLocker).createPlan(
        msg.sender,
        campaign.token,
        claimAmount,
        claim.start,
        claim.cliff,
        claim.rate,
        claim.period
      );
    } else if (campaign.tokenLockup == TokenLockup.Vesting) {
      IVestingTokenPlans(claim.tokenLocker).createPlan(
        msg.sender,
        campaign.token,
        claimAmount,
        claim.start,
        claim.cliff,
        claim.rate,
        claim.period,
        campaign.manager,
        false
      );
    }
  }

  function cancelCampaign(uint256 campaignId) external nonReentrant {
    Campaign memory campaign = campaigns[campaignId];
    require(campaign.manager == msg.sender, '!manager');
    delete campaigns[campaignId];
    delete claims[campaignId];
    TransferHelper.withdrawTokens(campaign.token, msg.sender, campaign.amount);
  }

  function verify(bytes32 root, bytes32[] memory proof, address claimer, uint256 amount) public pure returns (bool) {
    bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(claimer, amount))));
    require(MerkleProof.verify(proof, root, leaf), 'Invalid proof');
    return true;
  }
}
