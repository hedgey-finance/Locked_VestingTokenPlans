// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import './libraries/TransferHelper.sol';
import './libraries/TimelockLibrary.sol';
import './VotingVault.sol';

/**
 * @title An NFT representation of ownership of time locked tokens that unlock continuously per second
 * @notice The time locked tokens are redeemable by the owner of the NFT
 * @notice it uses the Enumerable extension to allow for easy lookup to pull balances of one account for multiple NFTs
 * it also uses a new ERC721 Delegate contract that allows users to delegate their NFTs to other wallets for the purpose of voting
 * @author alex michelsen aka icemanparachute
 */

contract TimeLockedTokenPlans is ERC721Enumerable, ReentrancyGuard {
  using Counters for Counters.Counter;
  Counters.Counter private _planIds;

  /// @dev baseURI is the URI directory where the metadata is stored
  string private baseURI;
  /// @dev bool to ensure uri has been set before admin can be deleted
  bool private uriSet;
  /// @dev admin for setting the baseURI;
  address internal admin;

  mapping(uint256 => address) internal votingVaults;

  /// @dev the timelock is the storage in a struct of the tokens that are currently being timelocked
  /// @dev token is the token address being timelocked
  /// @dev amount is the total amount of tokens in the timelock, which is comprised of the balance and the remainder
  /// @dev start is the start date when token timelock begins, this can be set at anytime including past and future
  /// @dev cliffDate is an optional field to add a single cliff date prior to which the tokens cannot be unlocked
  /// @dev rate is the number of tokens per second being timelocked
  struct Plan {
    address token;
    uint256 amount;
    uint256 start;
    uint256 cliff;
    uint256 rate;
    uint256 period;
  }

  /// @dev a mapping of the NFT tokenId from _tokenIds to the timelock structs to locate in storage
  mapping(uint256 => Plan) public plans;

  ///@notice Events when a new timelock and NFT is minted this event spits out all of the struct information
  event PlanCreated(
    uint256 indexed id,
    address indexed recipient,
    address indexed token,
    uint256 amount,
    uint256 start,
    uint256 cliff,
    uint256 end,
    uint256 rate,
    uint256 period
  );

  /// @notice event when the NFT is redeemed, there are two redemption types, partial and full redemption
  /// if the remainder == 0 then it is a full redemption and the NFT is burned, otherwise it is a partial redemption
  event PlanTokensUnlocked(uint256 indexed id, uint256 amountClaimed, uint256 planRemainder, uint256 resetDate);

  event VotingVaultCreated(uint256 indexed id, address vaultAddress);
  /// @notice event for when a new URI is set for the NFT metadata linking
  event URISet(string newURI);

  event AdminDeleted(address _admin);

  /// @notice the constructor function has two params:
  /// @param name is the name of the collection of NFTs
  /// @param symbol is the symbol for the NFT collection, typically an abbreviated version of the name
  constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    admin = msg.sender;
  }

  /// @dev internal function used by the standard ER721 function tokenURI to retrieve the baseURI privately held to visualize and get the metadata
  function _baseURI() internal view override returns (string memory) {
    return baseURI;
  }

  /// @notice function to set the base URI after the contract has been launched, only the admin can call
  /// @param _uri is the new baseURI for the metadata
  function updateBaseURI(string memory _uri) external {
    require(msg.sender == admin, '!ADMIN');
    baseURI = _uri;
    uriSet = true;
    emit URISet(_uri);
  }

  /// @notice function to delete the admin once the uri has been set
  function deleteAdmin() external {
    require(msg.sender == admin, '!ADMIN');
    require(uriSet, '!SET');
    delete admin;
    emit AdminDeleted(msg.sender);
  }

  /// @notice createPlan function is the function to mint a new NFT and simultaneously create a time locked timelock of tokens
  /// @param recipient is the recipient of the NFT. It can be the self minted to oneself, or minted to a different address than the caller of this function
  /// @param token is the token address of the tokens that will be locked inside the timelock
  /// @param amount is the total amount of tokens to be locked for the duration of the timelocking unlock period
  /// @param start is the start date for when the tokens start to become unlocked, this can be past dated, present or future dated using unix timestamp
  /// @param cliff is an optional paramater to allow a future single cliff date where tokens will be unlocked.
  /// If the start date of unlock is prior to the cliff, then on the cliff anything unlocked from the start will immediately be unlocekd at the cliffdate
  /// @param rate is the rate tokens are continuously unlocked, over the interval period.
  /// @param period is a regular frequency with which tokens unlock on a defined interval period, using seconds, but will typically represent 30 days, or 90 days. 


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
    _tokenIds.increment();
    uint256 newPlanId = _planIds.current();
    uint256 end = TimelockLibrary.endDate(start, amount, rate, interval);
    require(cliff <= end, 'SV12');
    TransferHelper.transferTokens(token, msg.sender, address(this), amount);
    plans[newPlanId] = Plan(token, amount, start, cliff, rate, period);
    _safeMint(recipient, newPlanId);
    emit PlanCreated(newPlanId, recipient, token, amount, start, cliff, end, rate, period);
  }

  function setupVoting(uint256 planId) external {
    require(ownerOf(planId) == msg.sender);
    Plan memory plan = plans[planId];
    VotingVault vault = new VotingVault(plan.token, msg.sender);
    tokenVaults[tokenId] = address(tv);
    TransferHelper.withdrawTokens(timelock.token, address(tv), timelock.amount);
    //event emitted
  }

  function delegatePlanTokens(uint256 planId, address delegatee) external {
    require(ownerOf(tokenId) == msg.sender);
    address vault = tokenVaults[tokenId];
    require(tokenVaults[tokenId] != address(0), 'no vault setup');
    TokenVault(vault).delegateTokens(delegatee);
  }

  /// @notice function to redeem a single or multiple NFT timelocks
  /// @param tokenIds is an array of tokens that are passed in to be redeemed
  function redeemPlans(uint256[] memory planIds) external nonReentrant {
    _redeemPlans(planIds);
  }

  /// @notice function to claim for all of my owned NFTs
  /// @dev pulls the balance and uses the enumerate function to redeem each NFT based on their index id
  /// this function will not revert if there is no balance, it will simply redeem all NFTs owned by the msg.sender that have a balance
  function redeemAllPlans() external nonReentrant {
    uint256 balance = balanceOf(msg.sender);
    uint256[] memory planIds = new uint256[](balance);
    for (uint256 i; i < balance; i++) {
      //check the balance of the vest first
      uint256 planId = _tokenOfOwnerByIndex(msg.sender, i);
      planIds[i] = planId;
    }
    _redeemPlans(planIds);
  }

  /// @dev function to redeem the multiple NFTs
  /// @dev internal method used for the redeemNFT and redeemAllNFTs to process multiple and avoid reentrancy
  function _redeemPlans(uint256[] memory planIds) internal {
    for (uint256 i; i < planIds.length; i++) {
      (uint256 balance, uint256 remainder, uint256 latestUnlock) = planBalanceOf(planIds[i], block.timestamp);
      if (balance > 0) _redeemPlan(msg.sender, planIds[i], balance, remainder, latestUnlock);
    }
  }

  /// @dev internal redeem function that performs all of the necessary checks, updates to storage and transfers of tokens to the NFT holder
  /// @param holder is the owner of the NFT, the msg.sender from the external calls
  /// @param tokenId is the id of the NFT
  function _redeemPlan(address holder, uint256 planId, uint256 balance, uint256 remainder, uint256 latestUnlock) internal {
    require(ownerOf(planId) == holder, '!holder');
    Plan storage plan = plans[planId];
    address vault = tokenVaults[planId];
    address token = plan.token;
    if (balance == plan.amount) {
      delete plan;
      delete tokenVaults[planId];
      _burn(planId);
    } else {
      plan.amount = remainder;
      plan.start = latestUnlock;
    }
    if(vault == address(0)) {
        TransferHelper.withdrawTokens(token, holder, balance);
    } else {
        VotingVault(vault).withdrawTokens(balance, holder);
    }
    emit PlanTokensUnlocked(planId, balance, remainder, latestUnlock);
  }

  /// @dev funtion to get the current balance and remainder of a given timelock, using the current block time
  /// @param tokenId is the NFT token ID
  function planBalanceOf(uint256 planId, uint256 timeStamp) public view returns (uint256 balance, uint256 remainder, uint256 latestUnlock) {
    Plan memory plan = plans[planId];
    (balance, remainder, latestUnlock) = TimelockLibrary.balanceAtTime(
      plan.start,
      plan.cliff,
      plan.amount,
      plan.rate,
      plan.period,
      timeStamp
    );
  }

  /// @dev function to calculate the end date in seconds of a given unlock timelock
  /// @param tokenId is the NFT token ID
  function planEnd(uint256 planId) external view returns (uint256 end) {
    Plan memory plan = plans[planId];
    end = TimelockLibrary.endDate(plan.start, plan.amount, plan.rate, plan.period);
  }

 
}