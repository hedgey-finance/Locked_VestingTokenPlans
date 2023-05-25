// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import './ERC721Delegate/ERC721Delegate.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import './libraries/TransferHelper.sol';
import './libraries/TimelockLibrary.sol';

/**
 * @title An NFT representation of ownership of time locked tokens that unlock continuously per second
 * @notice The time locked tokens are redeemable by the owner of the NFT
 * @notice it uses the Enumerable extension to allow for easy lookup to pull balances of one account for multiple NFTs
 * it also uses a new ERC721 Delegate contract that allows users to delegate their NFTs to other wallets for the purpose of voting
 * @author alex michelsen aka icemanparachute
 */

contract TimeLockedNFT is ERC721Delegate, ReentrancyGuard {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  /// @dev baseURI is the URI directory where the metadata is stored
  string private baseURI;
  /// @dev bool to ensure uri has been set before admin can be deleted
  bool private uriSet;
  /// @dev admin for setting the baseURI;
  address internal admin;

  /// @dev the timelock is the storage in a struct of the tokens that are currently being timelocked
  /// @dev token is the token address being timelocked
  /// @dev amount is the total amount of tokens in the timelock, which is comprised of the balance and the remainder
  /// @dev start is the start date when token timelock begins, this can be set at anytime including past and future
  /// @dev cliffDate is an optional field to add a single cliff date prior to which the tokens cannot be unlocked
  /// @dev rate is the number of tokens per second being timelocked
  struct Timelock {
    address token;
    uint256 amount;
    uint256 start;
    uint256 cliffDate;
    uint256 rate;
    uint256 interval;
  }

  /// @dev a mapping of the NFT tokenId from _tokenIds to the timelock structs to locate in storage
  mapping(uint256 => Timelock) public timelocks;

  ///@notice Events when a new timelock and NFT is minted this event spits out all of the struct information
  event NFTCreated(
    uint256 indexed id,
    address indexed recipient,
    address indexed token,
    uint256 amount,
    uint256 start,
    uint256 cliffDate,
    uint256 end,
    uint256 rate,
    uint256 interval
  );

  /// @notice event when the NFT is redeemed, there are two redemption types, partial and full redemption
  /// if the remainder == 0 then it is a full redemption and the NFT is burned, otherwise it is a partial redemption
  event NFTRedeemed(uint256 indexed id, uint256 balance, uint256 remainder, uint256 newStart);
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

  /// @notice createNFT function is the function to mint a new NFT and simultaneously create a time locked timelock of tokens
  /// @param recipient is the recipient of the NFT. It can be the self minted to oneself, or minted to a different address than the caller of this function
  /// @param token is the token address of the tokens that will be locked inside the timelock
  /// @param amount is the total amount of tokens to be locked for the duration of the timelocking unlock period
  /// @param start is the start date for when the tokens start to become unlocked, this can be past dated, present or future dated using unix timestamp
  /// @param cliffDate is an optional paramater to allow a future single cliff date where tokens will be unlocked.
  /// If the start date of unlock is prior to the cliff, then on the cliff anything unlocked from the start will immediately be unlocekd at the cliffdate
  /// @param rate is the rate tokens are continuously unlocked, over the interval period.
  /// @param interval is a regular frequency with which tokens unlock on a defined interval period, using seconds, but will typically represent 30 days, or 90 days. 


  function createNFT(
    address recipient,
    address token,
    uint256 amount,
    uint256 start,
    uint256 cliffDate,
    uint256 rate,
    uint256 interval
  ) external nonReentrant {
    require(recipient != address(0), '01');
    require(token != address(0), '02');
    require(amount > 0, '03');
    require(rate > 0, '04');
    require(rate <= amount, '05');
    require(amount % rate == 0,'06');
    _tokenIds.increment();
    uint256 newItemId = _tokenIds.current();
    uint256 end = TimelockLibrary.endDate(start, amount, rate, interval);
    require(cliffDate <= end, 'SV12');
    TransferHelper.transferTokens(token, msg.sender, address(this), amount);
    timelocks[newItemId] = Timelock(token, amount, start, cliffDate, rate, interval);
    _safeMint(recipient, newItemId);
    emit NFTCreated(newItemId, recipient, token, amount, start, cliffDate, end, rate, interval);
  }

  /// @dev function to delegate specific tokens to another wallet for voting
  /// @param delegate is the address of the wallet to delegate the NFTs to
  /// @param tokenIds is the array of tokens that we want to delegate
  function delegateTokens(address delegate, uint256[] memory tokenIds) external {
    for (uint256 i; i < tokenIds.length; i++) {
      _delegateToken(delegate, tokenIds[i]);
    }
  }

  /// @dev this function is to delegate all NFTs to another wallet address
  /// it pulls any tokens of the owner and delegates the NFT to the delegate address
  /// @param delegate is the address of the delegate
  function delegateAllNFTs(address delegate) external {
    uint256 balance = balanceOf(msg.sender);
    for (uint256 i; i < balance; i++) {
      uint256 tokenId = _tokenOfOwnerByIndex(msg.sender, i);
      _delegateToken(delegate, tokenId);
    }
  }

  /// @notice function to redeem a single or multiple NFT timelocks
  /// @param tokenIds is an array of tokens that are passed in to be redeemed
  function redeemNFTs(uint256[] memory tokenIds) external nonReentrant {
    _redeemNFTs(tokenIds);
  }

  /// @notice function to claim for all of my owned NFTs
  /// @dev pulls the balance and uses the enumerate function to redeem each NFT based on their index id
  /// this function will not revert if there is no balance, it will simply redeem all NFTs owned by the msg.sender that have a balance
  function redeemAllNFTs() external nonReentrant {
    uint256 balance = balanceOf(msg.sender);
    uint256[] memory tokenIds = new uint256[](balance);
    for (uint256 i; i < balance; i++) {
      //check the balance of the vest first
      uint256 tokenId = _tokenOfOwnerByIndex(msg.sender, i);
      tokenIds[i] = tokenId;
    }
    _redeemNFTs(tokenIds);
  }

  /// @dev function to redeem the multiple NFTs
  /// @dev internal method used for the redeemNFT and redeemAllNFTs to process multiple and avoid reentrancy
  function _redeemNFTs(uint256[] memory tokenIds) internal {
    for (uint256 i; i < tokenIds.length; i++) {
      (uint256 balance, ) = timelockBalanceOf(tokenIds[i]);
      if (balance > 0) _redeemNFT(msg.sender, tokenIds[i]);
    }
  }

  /// @dev internal redeem function that performs all of the necessary checks, updates to storage and transfers of tokens to the NFT holder
  /// @param holder is the owner of the NFT, the msg.sender from the external calls
  /// @param tokenId is the id of the NFT
  function _redeemNFT(address holder, uint256 tokenId) internal returns (uint256 remainder) {
    require(ownerOf(tokenId) == holder, 'SV06');
    Timelock memory timelock = timelocks[tokenId];
    uint256 balance;
    (balance, remainder) = TimelockLibrary.balanceAtTime(
      timelock.start,
      timelock.cliffDate,
      timelock.amount,
      timelock.rate,
      timelock.interval,
      block.timestamp
    );
    require(balance > 0, 'SV08');
    if (balance == timelock.amount) {
      delete timelocks[tokenId];
      _burn(tokenId);
    } else {
      timelocks[tokenId].amount -= balance;
      timelocks[tokenId].start = block.timestamp;
    }
    TransferHelper.withdrawTokens(timelock.token, holder, balance);
    emit NFTRedeemed(tokenId, balance, remainder, block.timestamp);
  }

  /// @dev funtion to get the current balance and remainder of a given timelock, using the current block time
  /// @param tokenId is the NFT token ID
  function timelockBalanceOf(uint256 tokenId) public view returns (uint256 balance, uint256 remainder) {
    Timelock memory timelock = timelocks[tokenId];
    (balance, remainder) = TimelockLibrary.balanceAtTime(
      timelock.start,
      timelock.cliffDate,
      timelock.amount,
      timelock.rate,
      timelock.interval,
      block.timestamp
    );
  }

  /// @dev function to calculate the end date in seconds of a given unlock timelock
  /// @param tokenId is the NFT token ID
  function getTimelockEnd(uint256 tokenId) external view returns (uint256 end) {
    Timelock memory timelock = timelocks[tokenId];
    end = TimelockLibrary.endDate(timelock.start, timelock.amount, timelock.rate, timelock.interval);
  }

  /// @dev lockedBalances is a function that will enumerate all of the tokens of a given holder, and aggregate those balances up
  /// this is useful for snapshot voting and other view methods to see the total balances of a given user for a single token
  /// @param holder is the owner of the NFTs
  /// @param token is the address of the token that is locked by each of the NFTs
  function lockedBalances(address holder, address token) external view returns (uint256 lockedBalance) {
    uint256 holdersBalance = balanceOf(holder);
    for (uint256 i; i < holdersBalance; i++) {
      uint256 tokenId = _tokenOfOwnerByIndex(holder, i);
      Timelock memory timelock = timelocks[tokenId];
      if (token == timelock.token) {
        lockedBalance += timelock.amount;
      }
    }
  }

  /// @dev delegatedBAlances is a function that will enumerate all of the tokens of a given delegate, and aggregate those balances up
  /// this is useful for snapshot voting and other view methods to see the total balances of a given user for a single token
  /// @param delegate is the wallet that has been delegated NFTs
  /// @param token is the address of the token that is locked by each of the NFTs
  function delegatedBalances(address delegate, address token) external view returns (uint256 delegatedBalance) {
    uint256 delegateBalance = balanceOfDelegate(delegate);
    for (uint256 i; i < delegateBalance; i++) {
      uint256 tokenId = tokenOfDelegateByIndex(delegate, i);
      Timelock memory timelock = timelocks[tokenId];
      if (token == timelock.token) {
        delegatedBalance += timelock.amount;
      }
    }
  }
}