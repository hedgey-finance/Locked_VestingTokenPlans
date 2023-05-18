// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.20;

// import '@openzeppelin/contracts/utils/Counters.sol';
// import './ERC721Delegate/ERC721Delegate.sol';
// import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
// import './libraries/TransferHelper.sol';

// contract HedgeyTimeLocks is ERC721Delegate, ReentrancyGuard {
//   using Counters for Counters.Counter;
//   Counters.Counter private _tokenIds;

//   /// @dev baseURI is the URI directory where the metadata is stored
//   string private baseURI;
//   /// @dev bool to check if the uri has been set
//   bool private uriSet;
//   /// @dev admin for setting the baseURI;
//   address private admin;

//   struct Timelock {
//     address token;
//     uint256 amount;
//     uint256 cliffAmount;
//     uint256 lockAmount;
//     uint16 locks;
//     uint256 interval;
//     uint256 nextUnlock;
//   }

//   mapping(uint256 => Timelock) public timelocks;

//   //events
//   event NFTCreated(
//     uint256 indexed id,
//     address indexed recipient,
//     address indexed token,
//     uint256 totalAmount,
//     uint256 cliffAmount,
//     uint256 lockAmount,
//     uint16 totalLocks,
//     uint256 interval
//   );
//   event NFTRedeemed(
//     uint256 indexed id,
//     uint256 redemption,
//     uint256 cliffsRedeemed,
//     uint256 remainder,
//     uint256 remainingCliffs
//   );
//   event URISet(string newURI);
//   event AdminDeleted(address _admin);

//   constructor(string memory name, string memory symbol) ERC721(name, symbol) {
//     admin = msg.sender;
//   }

//   function createNFT(
//     address recipient,
//     address token,
//     uint256 lockAmount,
//     uint256 cliffAmount,
//     uint16 locks,
//     uint256 interval,
//     uint256 start
//   ) external nonReentrant {
//     require(recipient != address(0), '!zero');
//     require(token != address(0), '!zero');
//     _tokenIds.increment();
//     uint256 newTokenId = _tokenIds.current();
//     uint256 total = lockAmount * (locks - 1) + cliffAmount;
//     TransferHelper.transferTokens(token, msg.sender, address(this), total);
//     timelocks[newTokenId] = Timelock(token, total, lockAmount, cliffAmount, locks, interval, start);
//     _safeMint(recipient, newTokenId);
//     emit NFTCreated(newTokenId, recipient, token, total, lockAmount, cliffAmount, locks, interval, start);
//   }


//   function redeemNFTs(uint256[] memory tokenIds) external nonReentrant {
//     for (uint256 i; i < tokenIds.length; i++) {
//       _redeemNFT(msg.sender, tokenIds[i]);
//     }
//   }

//   function _redeemNFT(address holder, uint256 tokenId) internal {
//     require(ownerOf(tokenId) == holder);
    
//   }

//   function redeemableBalance(uint256 tokenId) public view returns (uint256 balance, uint16 redeemableCliffs) {
//     Timelock memory tl = timelocks[tokenId];
//     if (tl.unlock > block.timestamp) {
//         return (0, 0);
//     } else {
//         uint16 availableUnlocks = (block.timestamp - tl.unlock) / tl.interval;
//     }
//   }

//   /// @dev function to delegate specific tokens to another wallet for voting
//   /// @param delegate is the address of the wallet to delegate the NFTs to
//   /// @param tokenIds is the array of tokens that we want to delegate
//   function delegateTokens(address delegate, uint256[] memory tokenIds) external {
//     for (uint256 i; i < tokenIds.length; i++) {
//       _delegateToken(delegate, tokenIds[i]);
//     }
//   }

//   /// @dev this function is to delegate all NFTs to another wallet address
//   /// it pulls any tokens of the owner and delegates the NFT to the delegate address
//   /// @param delegate is the address of the delegate
//   function delegateAllNFTs(address delegate) external {
//     uint256 balance = balanceOf(msg.sender);
//     for (uint256 i; i < balance; i++) {
//       uint256 tokenId = _tokenOfOwnerByIndex(msg.sender, i);
//       _delegateToken(delegate, tokenId);
//     }
//   }

//   /// @dev lockedBalances is a function that will enumerate all of the tokens of a given holder, and aggregate those balances up
//   /// this is useful for snapshot voting and other view methods to see the total balances of a given user for a single token
//   /// @param holder is the owner of the NFTs
//   /// @param token is the address of the token that is locked by each of the NFTs
//   function lockedBalances(address holder, address token) external view returns (uint256 lockedBalance) {
//     uint256 holdersBalance = balanceOf(holder);
//     for (uint256 i; i < holdersBalance; i++) {
//       uint256 tokenId = _tokenOfOwnerByIndex(holder, i);
//       Timelock memory tl = timelocks[tokenId];
//       if (token == tl.token) {
//         lockedBalance += tl.remainder;
//       }
//     }
//   }

//   /// @dev delegatedBAlances is a function that will enumerate all of the tokens of a given delegate, and aggregate those balances up
//   /// this is useful for snapshot voting and other view methods to see the total balances of a given user for a single token
//   /// @param delegate is the wallet that has been delegated NFTs
//   /// @param token is the address of the token that is locked by each of the NFTs
//   function delegatedBalances(address delegate, address token) external view returns (uint256 delegatedBalance) {
//     uint256 delegateBalance = balanceOfDelegate(delegate);
//     for (uint256 i; i < delegateBalance; i++) {
//       uint256 tokenId = tokenOfDelegateByIndex(delegate, i);
//       Timelock memory tl = timelocks[tokenId];
//       if (token == tl.token) {
//         delegatedBalance += tl.remainder;
//       }
//     }
//   }
// }
