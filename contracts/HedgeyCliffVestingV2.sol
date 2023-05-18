// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import '@openzeppelin/contracts/utils/Counters.sol';
import './ERC721Delegate/ERC721Delegate.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import './libraries/TransferHelper.sol';

contract HedgeyCliffLocksV2 is ERC721Delegate, ReentrancyGuard {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  /// @dev baseURI is the URI directory where the metadata is stored
  string private baseURI;
  /// @dev bool to check if the uri has been set
  bool private uriSet;
  /// @dev admin for setting the baseURI;
  address private admin;

  struct Timelock {
    address token;
    uint256 remainder;
    uint256 firstCliffAmount;
    uint256 cliffAmount;
    uint16 remainingCliffs;
    address vestingAdmin;
  }

  mapping(uint256 => Timelock) public timelocks;
  mapping(uint256 => uint256[]) public cliffs;

  //events
  event NFTCreated(
    uint256 indexed id,
    address indexed recipient,
    address indexed token,
    uint256 totalAmount,
    uint256 firstCliffAmount,
    uint256 cliffAmount,
    uint16 totalCliffs,
    address vestingAdmin
  );
  event NFTRedeemed(
    uint256 indexed id,
    uint256 redemption,
    uint256 cliffsRedeemed,
    uint256 remainder,
    uint256 remainingCliffs
  );
  event URISet(string newURI);
  event AdminDeleted(address _admin);

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    admin = msg.sender;
  }

  function createNFT(
    address recipient,
    address token,
    uint256 firstCliffAmount,
    uint256 cliffAmount,
    uint256[] memory unlocks,
    address vestingAdmin
  ) external nonReentrant {
    require(checkMint(recipient, firstCliffAmount, cliffAmount, unlocks));
    _tokenIds.increment();
    uint256 newTokenId = _tokenIds.current();
    uint256 total = firstCliffAmount + cliffAmount * (unlocks.length - 1);
    TransferHelper.transferTokens(token, msg.sender, address(this), total);
    timelocks[newTokenId] = Timelock(token, total, firstCliffAmount, cliffAmount, uint16(unlocks.length), vestingAdmin);
    cliffs[newTokenId] = unlocks;
    _safeMint(recipient, newTokenId);
    emit NFTCreated(
      newTokenId,
      recipient,
      token,
      total,
      firstCliffAmount,
      cliffAmount,
      uint16(unlocks.length),
      vestingAdmin
    );
  }

  function createNFTBatch(
    address[] memory recipients,
    address token,
    uint256[] memory firstCliffAmounts,
    uint256[] memory cliffAmounts,
    uint256[][] memory unlocksArr,
    address vestingAdmin,
    uint256 sumTotal
  ) external nonReentrant {
    require(recipients.length == firstCliffAmounts.length, 'AR01');
    require(firstCliffAmounts.length == cliffAmounts.length, 'AR02');
    require(cliffAmounts.length == unlocksArr.length, 'AR03');
    TransferHelper.transferTokens(token, msg.sender, address(this), sumTotal);
    uint256 amountCheck;
    //uint256[] tokenIds = new uint256[](recipients.length);
    for (uint8 i; i < recipients.length; i++) {
      require(checkMint(recipients[i], firstCliffAmounts[i], cliffAmounts[i], unlocksArr[i]));
      _tokenIds.increment();
      uint256 newTokenId = _tokenIds.current();
      uint256 total = firstCliffAmounts[i] + cliffAmounts[i] * (unlocksArr[i].length - 1);
      amountCheck += total;
      timelocks[newTokenId] = Timelock(
        token,
        total,
        firstCliffAmounts[i],
        cliffAmounts[i],
        uint16(unlocksArr[i].length),
        vestingAdmin
      );
      cliffs[newTokenId] = unlocksArr[i];
      _safeMint(recipients[i], newTokenId);
      //tokenIds[i] = newTokenId;
      emit NFTCreated(
        newTokenId,
        recipients[i],
        token,
        total,
        firstCliffAmounts[i],
        cliffAmounts[i],
        uint16(unlocksArr[i].length),
        vestingAdmin
      );
    }
    require(amountCheck == sumTotal, 'total error');
    //emit NFTBatchCreated(tokenIds, recipients, token, sumTotal, firstCliffAmounts, cliffAmounts)
  }

  function checkMint(
    address recipient,
    uint256 firstCliffAmount,
    uint256 cliffAmount,
    uint256[] memory unlocks
  ) internal pure returns (bool) {
    require(recipient != address(0), '!zero');
    require(unlocks.length > 0, 'arr');
    require(cliffAmount > 0, 'zero');
    require(firstCliffAmount > 0, 'f_zero');
    for (uint16 i; i < unlocks.length; i++) {
      if (i + 1 < unlocks.length) require(unlocks[i] > unlocks[i + 1], 'unlock order error');
    }
    return true;
  }

  function partialRedeemNFT(uint256 tokenId, uint16 unlocks) external nonReentrant {
    _redeemNFT(msg.sender, tokenId, unlocks);
  }

  function redeemNFTs(uint256[] memory tokenIds) external nonReentrant {
    //get available cliffs that can be redeemed
    for (uint256 i; i < tokenIds.length; i++) {
      _redeemNFT(msg.sender, tokenIds[i], getAvailableUnlocks(tokenIds[i]));
    }
  }

  function getAvailableUnlocks(uint256 tokenId) public view returns (uint16 unlocks) {
    uint16 remainingCliffs = timelocks[tokenId].remainingCliffs;
    for (uint16 i = remainingCliffs; i > 0; i--) {
      if (cliffs[tokenId][i - 1] <= block.timestamp) {
        unlocks++;
      } else {
        break;
      }
    }
  }

  function _redeemNFT(address holder, uint256 tokenId, uint16 unlocks) internal {
    require(ownerOf(tokenId) == holder, 'not owner');
    Timelock memory tl = timelocks[tokenId];
    uint256 firstCliff = tl.firstCliffAmount;
    uint256 redemption;
    uint256 remainder;
    uint16 remCliff = tl.remainingCliffs;
    for (uint16 i = remCliff; i > remCliff - unlocks; i--) {
      uint256 cliff = cliffs[tokenId][i - 1];
      require(cliff <= block.timestamp, 'not redeemable');
      if (firstCliff > 0) {
        redemption += firstCliff;
        firstCliff = 0;
        cliffs[tokenId].pop();
      } else {
        redemption += tl.cliffAmount;
        cliffs[tokenId].pop();
      }
    }
    if (unlocks == tl.remainingCliffs) {
      delete timelocks[tokenId];
      delete cliffs[tokenId];
      remainder = 0;
      remCliff = 0;
    } else {
      timelocks[tokenId].remainingCliffs -= unlocks;
      remCliff = timelocks[tokenId].remainingCliffs;
      timelocks[tokenId].remainder -= redemption;
      remainder = timelocks[tokenId].remainder;
    }
    TransferHelper.withdrawTokens(tl.token, holder, redemption);
    emit NFTRedeemed(tokenId, redemption, unlocks, remainder, remCliff);
  }

  function revokeNFTs(uint256[] memory tokenIds) external nonReentrant {
    for (uint8 i; i < tokenIds.length; i++) {
      _revokeNFT(msg.sender, tokenIds[i]);
    }
  }

  function _revokeNFT(address vestingAdmin, uint256 tokenId) internal {
    Timelock memory tl = timelocks[tokenId];
    require(tl.vestingAdmin == vestingAdmin, '!vADMIN');
    uint256 unlocks = getAvailableUnlocks(tokenId);
    require(unlocks < tl.remainingCliffs, 'nothing to revoke');
    uint256 firstCliff = tl.firstCliffAmount;
    uint256 redemption;
    uint16 remCliff = tl.remainingCliffs;
    if (unlocks > 0) {
      for (uint16 i = remCliff; i > remCliff - unlocks; i--) {
        if (firstCliff > 0) {
          redemption += firstCliff;
          firstCliff = 0;
        } else {
          redemption += tl.cliffAmount;
        }
      }
    }
    uint256 remainder = tl.remainder - redemption;
    delete timelocks[tokenId];
    delete cliffs[tokenId];
    TransferHelper.withdrawTokens(tl.token, ownerOf(tokenId), redemption);
    TransferHelper.withdrawTokens(tl.token, vestingAdmin, remainder);
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
