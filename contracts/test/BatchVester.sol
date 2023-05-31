// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;


import '../libraries/TransferHelper.sol';

interface IVestingNFT {
  function createNFT(
    address recipient,
    address token,
    uint256 amount,
    uint256 start,
    uint256 cliffDate,
    uint256 rate,
    address vestingAdmin
  ) external;

  function createLockedNFT(
    address recipient,
    address token,
    uint256 amount,
    uint256 start,
    uint256 cliffDate,
    uint256 rate,
    address vestingAdmin,
    uint256 unlockDate,
    bool transferLocker
  ) external;
}

contract BatchVester {
  event BatchCreated(uint256 mintType);

  /// @notice craeate a batch of vesting NFTs with the same token and same vesting Admin to various recipients, amounts, start dates, cliffs and rates
  /// @param vester is the address of the StreamVestingNFT contrac this points to, either the StreamingHedgeys or the StreamingBoundHedgeys
  /// @param recipients is the array of addresses for those wallets receiving the streams
  /// @param token is the address of the token to be locked inside the NFTs and linearly unlocked to the recipients
  /// @param amounts is the array of the amount of tokens to be locked in each NFT, each directly related in sequence to the recipient and other arrays
  /// @param starts is the array of start dates that define when each NFT will begin linearly unlocking
  /// @param cliffs is the array of cliff dates that define each cliff date for the NFT stream
  /// @param rates is the array of per second rates that each NFT will unlock at the rate of
  /// @param vestingAdmin is the address of the administrator for the vesting plan for the batch of recipients. The vesting admin can revoke tokens at any time.

  function createBatch(
    address vester,
    address[] memory recipients,
    address token,
    uint256[] memory amounts,
    uint256[] memory starts,
    uint256[] memory cliffs,
    uint256[] memory rates,
    address vestingAdmin
  ) external {
    uint256 totalAmount;
    for (uint256 i; i < amounts.length; i++) {
      require(amounts[i] > 0, 'SV04');
      totalAmount += amounts[i];
    }
    _createBatch(vester, recipients, token, amounts, totalAmount, starts, cliffs, rates, vestingAdmin);
  }

  /// @notice craeate a batch of vesting NFTs with the same token and same vesting Admin to various recipients, amounts, start dates, cliffs and rates
  /// this contract emits a special BatchCreated event with the mintType param for internal analytics and tagging
  /// @param vester is the address of the StreamVestingNFT contrac this points to, either the StreamingHedgeys or the StreamingBoundHedgeys
  /// @param recipients is the array of addresses for those wallets receiving the streams
  /// @param token is the address of the token to be locked inside the NFTs and linearly unlocked to the recipients
  /// @param amounts is the array of the amount of tokens to be locked in each NFT, each directly related in sequence to the recipient and other arrays
  /// @param starts is the array of start dates that define when each NFT will begin linearly unlocking
  /// @param cliffs is the array of cliff dates that define each cliff date for the NFT stream
  /// @param rates is the array of per second rates that each NFT will unlock at the rate of
  /// @param vestingAdmin is the address of the administrator for the vesting plan for the batch of recipients. The vesting admin can revoke tokens at any time.
  /// @param mintType is an internal identifier used by Hedgey Applications to record special identifiers for special metadata creation and internal analytics tagging

//   function createBatch(
//     address vester,
//     address[] memory recipients,
//     address token,
//     uint256[] memory amounts,
//     uint256[] memory starts,
//     uint256[] memory cliffs,
//     uint256[] memory rates,
//     address vestingAdmin,
//     uint256 mintType
//   ) external {
//     uint256 totalAmount;
//     for (uint256 i; i < amounts.length; i++) {
//       require(amounts[i] > 0, 'SV04');
//       totalAmount += amounts[i];
//     }
//     emit BatchCreated(mintType);
//     _createBatch(vester, recipients, token, amounts, totalAmount, starts, cliffs, rates, vestingAdmin);
//   }

  /// @notice craeate a batch of vesting NFTs with the same token and same vesting Admin to various recipients, amounts, start dates, cliffs and rates
  /// this call has the additional field for creating vesting tokens with an additional unlockDate parameter and the transferableNFTLocker
  /// @param vester is the address of the StreamVestingNFT contrac this points to, either the StreamingHedgeys or the StreamingBoundHedgeys
  /// @param recipients is the array of addresses for those wallets receiving the streams
  /// @param token is the address of the token to be locked inside the NFTs and linearly unlocked to the recipients
  /// @param amounts is the array of the amount of tokens to be locked in each NFT, each directly related in sequence to the recipient and other arrays
  /// @param starts is the array of start dates that define when each NFT will begin linearly unlocking
  /// @param cliffs is the array of cliff dates that define each cliff date for the NFT stream
  /// @param rates is the array of per second rates that each NFT will unlock at the rate of
  /// @param vestingAdmin is the address of the administrator for the vesting plan for the batch of recipients. The vesting admin can revoke tokens at any time.
  /// @param unlocks is an array of unlockDates. The unlock dates are an additional vesting plan modifier,
  /// whereby vested tokens are subject to a lockup period that may be in excess of the cliff date and vesting end date
  /// the unlock date is used typically by teams who are just deploying their tokens for the first time, and have a vesting period with a universal unlock date
  /// where the recipients cannot sell or unlock their tokens before, even if their tokens are vested.
  /// @param transferableNFTLocker is a boolean that describes the transferability of tokens that are vested and locked. This is a special circumstance where
  /// a recipient has vested some tokens and the remaining amount are revoked, but the vested amount are subject to a lockup period in the future.
  /// When the remaining tokens are revoked, the vested amount will be transferred and mint a StreamingNFT that will lock the tokens until the unlock date
  /// there are two versions of the StreamingNFT, transferable and non-transferable. This boolean defines whether the locked tokens are locked in the transferable or non-transferable StreamingNFT contract

  function createLockedBatch(
    address vester,
    address[] memory recipients,
    address token,
    uint256[] memory amounts,
    uint256[] memory starts,
    uint256[] memory cliffs,
    uint256[] memory rates,
    address vestingAdmin,
    uint256[] memory unlocks,
    bool transferableNFTLocker
  ) external {
    uint256 totalAmount;
    for (uint256 i; i < amounts.length; i++) {
      require(amounts[i] > 0, 'SV04');
      totalAmount += amounts[i];
    }
    _createLockedBatch(
      vester,
      recipients,
      token,
      amounts,
      totalAmount,
      starts,
      cliffs,
      rates,
      vestingAdmin,
      unlocks,
      transferableNFTLocker
    );
  }

  /// @notice craeate a batch of vesting NFTs with the same token and same vesting Admin to various recipients, amounts, start dates, cliffs and rates
  /// this call has the additional field for creating vesting tokens with an additional unlockDate parameter and the transferableNFTLocker
  /// @param vester is the address of the StreamVestingNFT contrac this points to, either the StreamingHedgeys or the StreamingBoundHedgeys
  /// @param recipients is the array of addresses for those wallets receiving the streams
  /// @param token is the address of the token to be locked inside the NFTs and linearly unlocked to the recipients
  /// @param amounts is the array of the amount of tokens to be locked in each NFT, each directly related in sequence to the recipient and other arrays
  /// @param starts is the array of start dates that define when each NFT will begin linearly unlocking
  /// @param cliffs is the array of cliff dates that define each cliff date for the NFT stream
  /// @param rates is the array of per second rates that each NFT will unlock at the rate of
  /// @param vestingAdmin is the address of the administrator for the vesting plan for the batch of recipients. The vesting admin can revoke tokens at any time.
  /// @param unlocks is an array of unlockDates. The unlock dates are an additional vesting plan modifier,
  /// whereby vested tokens are subject to a lockup period that may be in excess of the cliff date and vesting end date
  /// the unlock date is used typically by teams who are just deploying their tokens for the first time, and have a vesting period with a universal unlock date
  /// where the recipients cannot sell or unlock their tokens before, even if their tokens are vested.
  /// @param transferableNFTLocker is a boolean that describes the transferability of tokens that are vested and locked. This is a special circumstance where
  /// a recipient has vested some tokens and the remaining amount are revoked, but the vested amount are subject to a lockup period in the future.
  /// When the remaining tokens are revoked, the vested amount will be transferred and mint a StreamingNFT that will lock the tokens until the unlock date
  /// there are two versions of the StreamingNFT, transferable and non-transferable. This boolean defines whether the locked tokens are locked in the transferable or non-transferable StreamingNFT contract
  /// @param mintType is an internal identifier used by Hedgey Applications to record special identifiers for special metadata creation and internal analytics tagging

  function createLockedBatch(
    address vester,
    address[] memory recipients,
    address token,
    uint256[] memory amounts,
    uint256[] memory starts,
    uint256[] memory cliffs,
    uint256[] memory rates,
    address vestingAdmin,
    uint256[] memory unlocks,
    bool transferableNFTLocker,
    uint256 mintType
  ) external {
    uint256 totalAmount;
    for (uint256 i; i < amounts.length; i++) {
      require(amounts[i] > 0, 'SV04');
      totalAmount += amounts[i];
    }
    emit BatchCreated(mintType);
    _createLockedBatch(
      vester,
      recipients,
      token,
      amounts,
      totalAmount,
      starts,
      cliffs,
      rates,
      vestingAdmin,
      unlocks,
      transferableNFTLocker
    );
  }

  /// @notice this is the internal function that is called by the external createBatch function, with all of its parameters
  /// the only new parameter is the totalAmount, which this function takes from the createBatch function to pull all of the tokens into this contract first
  /// and then iterate an array to begin minting vesting NFTs
  function _createBatch(
    address vester,
    address[] memory recipients,
    address token,
    uint256[] memory amounts,
    uint256 totalAmount,
    uint256[] memory starts,
    uint256[] memory cliffs,
    uint256[] memory rates,
    address vestingAdmin
  ) internal {
    require(
      recipients.length == amounts.length &&
        amounts.length == starts.length &&
        starts.length == cliffs.length &&
        cliffs.length == rates.length,
      'array length error'
    );
    TransferHelper.transferTokens(token, msg.sender, address(this), totalAmount);
    SafeERC20.safeIncreaseAllowance(IERC20(token), vester, totalAmount);
    for (uint256 i; i < recipients.length; i++) {
      IVestingNFT(vester).createNFT(recipients[i], token, amounts[i], starts[i], cliffs[i], rates[i], vestingAdmin);
    }
  }

  /// @notice this is the internal function that is called by the external createLockedBatch function, with all of its parameters
  /// the only new parameter is the totalAmount, which this function takes from the createLockedBatch function to pull all of the tokens into this contract first
  /// and then iterate an array to begin minting vesting NFTs
  function _createLockedBatch(
    address vester,
    address[] memory recipients,
    address token,
    uint256[] memory amounts,
    uint256 totalAmount,
    uint256[] memory starts,
    uint256[] memory cliffs,
    uint256[] memory rates,
    address vestingAdmin,
    uint256[] memory unlocks,
    bool transferableNFTLocker
  ) internal {
    require(
      recipients.length == amounts.length &&
        amounts.length == starts.length &&
        starts.length == cliffs.length &&
        cliffs.length == rates.length &&
        unlocks.length == cliffs.length,
      'array length error'
    );
    TransferHelper.transferTokens(token, msg.sender, address(this), totalAmount);
    SafeERC20.safeIncreaseAllowance(IERC20(token), vester, totalAmount);
    for (uint256 i; i < recipients.length; i++) {
      IVestingNFT(vester).createLockedNFT(
        recipients[i],
        token,
        amounts[i],
        starts[i],
        cliffs[i],
        rates[i],
        vestingAdmin,
        unlocks[i],
        transferableNFTLocker
      );
    }
  }
}