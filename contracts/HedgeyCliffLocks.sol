// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import '@openzeppelin/contracts/utils/Counters.sol';
import './ERC721Delegate/ERC721Delegate.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import './libraries/TransferHelper.sol';

contract HedgeyCliffLocks is ERC721Delegate, ReentrancyGuard {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  /// @dev baseURI is the URI directory where the metadata is stored
  string private baseURI;
  /// @dev bool to check if the uri has been set
  bool private uriSet;
  /// @dev admin for setting the baseURI;
  address private admin;

  struct Cliff {
    uint256 amount;
    uint256 unlock;
  }

  struct Timelock {
    address token;
    uint256 remainder;
    uint16 remainingCliffs;
  }

  mapping(uint256 => Timelock) public timelocks;
  mapping(uint256 => Cliff[]) public cliffs;

  //events
  event NFTCreated(uint256 indexed id, address indexed recipient, address indexed token, uint256[] amounts, uint256[] unlocks);
  event NFTRedeemed(uint256 indexed id, uint256 redemption, uint256 cliffsRedeemed, uint256 remainder, uint256 remainingCliffs);
  event URISet(string newURI);
  event AdminDeleted(address _admin);

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    admin = msg.sender;
  }

  function createNFT(
    address recipient,
    address token,
    uint256[] memory amounts,
    uint256[] memory unlocks
  ) external nonReentrant {
    require(recipient != address(0), '!zero');
    require(token != address(0), '!zero');
    require(amounts.length == unlocks.length, 'array');
    require(amounts.length > 0, 'no cliffs');
    _tokenIds.increment();
    uint256 newTokenId = _tokenIds.current();
    uint256 total;
    for (uint16 i; i < amounts.length; i++) {
      require(amounts[i] > 0, 'no amount');
      // need the unlocks to be organized from last to first
      if (i + 1 < unlocks.length) require(unlocks[i] > unlocks[i + 1], 'unlock order error');
      total += amounts[i];
      Cliff memory cliff = Cliff(amounts[i], unlocks[i]);
      cliffs[newTokenId].push(cliff);
    }
    TransferHelper.transferTokens(token, msg.sender, address(this), total);
    timelocks[newTokenId] = Timelock(token, total, uint16(unlocks.length));
    _safeMint(recipient, newTokenId);
    emit NFTCreated(newTokenId, recipient, token, amounts, unlocks);
  }

  function partialRedeemNFT(uint256 tokenId, uint16 unlocks) external nonReentrant {
    require(ownerOf(tokenId) == msg.sender);
    Timelock memory tl = timelocks[tokenId];
    require(unlocks < tl.remainingCliffs, 'total redemption');
    uint256 redemption;
    for (uint16 i = tl.remainingCliffs; i > tl.remainingCliffs - unlocks; i--) {
      Cliff memory cliff = cliffs[tokenId][i-1];
      require(cliff.unlock < block.timestamp && cliff.amount > 0);
      // if cliff is in the past, unlockable, add amount to redemption
      redemption += cliff.amount;
      // pop off the last cliff
      cliffs[tokenId].pop();
    }
    timelocks[tokenId].remainingCliffs -= unlocks;
    timelocks[tokenId].remainder -= redemption;
    TransferHelper.withdrawTokens(tl.token, msg.sender, redemption);
    emit NFTRedeemed(tokenId, redemption, unlocks, timelocks[tokenId].remainder, timelocks[tokenId].remainingCliffs);
  }

  function redeemNFTs(uint256[] memory tokenIds) external nonReentrant {
    for (uint256 i; i < tokenIds.length; i++) {
      _redeemNFT(msg.sender, tokenIds[i]);
    }
  }


  function _redeemNFT(address holder, uint256 tokenId) internal {
    require(ownerOf(tokenId) == holder);
    (uint256 redemption, uint16 rc) = redeemableBalance(tokenId);
    require(redemption > 0, 'nothing to redeem');
    Timelock memory tl = timelocks[tokenId];
    // update storage variables
    if (tl.remainder == redemption) {
      delete timelocks[tokenId];
      delete cliffs[tokenId];
      _burn(tokenId);
    } else {
      timelocks[tokenId].remainingCliffs -= rc;
      timelocks[tokenId].remainder -= redemption;
      // since everything is organized with the soonest date last in the array, just pop off the number of cliffs redeemed
      for (uint16 i; i < rc; i++) {
        // pop each one of the cliffs that was redeemed
        cliffs[tokenId].pop();
      }
      require(cliffs[tokenId].length == timelocks[tokenId].remainingCliffs, 'safety check');
    }
    TransferHelper.withdrawTokens(tl.token, holder, redemption);
    emit NFTRedeemed(tokenId, redemption, rc, timelocks[tokenId].remainder, timelocks[tokenId].remainingCliffs);
  }

  

  function redeemableBalance(uint256 tokenId) public view returns (uint256 balance, uint16 redeemableCliffs) {
    // takes current block time, looks up all of the indexes to find how many are in the future
    uint16 remainingCliffs = timelocks[tokenId].remainingCliffs;
    for (uint16 i = remainingCliffs; i > 0; i--) {
      Cliff memory cliff = cliffs[tokenId][i-1];
      if (cliff.unlock < block.timestamp && cliff.amount > 0) {
        balance += cliff.amount;
        redeemableCliffs++;
      }
    }
  }

  /// @dev function to delegate specific tokens to another wallet for voting
  /// @param delegate is the address of the wallet to delegate the NFTs to
  /// @param tokenIds is the array of tokens that we want to delegate
  function delegateTokens(address delegate, uint256[] memory tokenIds) external {
    for (uint256 i; i < tokenIds.length; i++) {
      _delegateToken(delegate, tokenIds[i]);
    }
  }


  /// @dev lockedBalances is a function that will enumerate all of the tokens of a given holder, and aggregate those balances up
  /// this is useful for snapshot voting and other view methods to see the total balances of a given user for a single token
  /// @param holder is the owner of the NFTs
  /// @param token is the address of the token that is locked by each of the NFTs
  function lockedBalances(address holder, address token) external view returns (uint256 lockedBalance) {
    uint256 holdersBalance = balanceOf(holder);
    for (uint256 i; i < holdersBalance; i++) {
      uint256 tokenId = _tokenOfOwnerByIndex(holder, i);
      Timelock memory tl = timelocks[tokenId];
      if (token == tl.token) {
        lockedBalance += tl.remainder;
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
      Timelock memory tl = timelocks[tokenId];
      if (token == tl.token) {
        delegatedBalance += tl.remainder;
      }
    }
  }
}
