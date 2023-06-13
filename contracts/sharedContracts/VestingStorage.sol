// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import '../libraries/TimelockLibrary.sol';

contract VestingStorage {
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
    address vestingAdmin;
    bool adminTransferOBO;
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
    uint256 period,
    address vestingAdmin,
    bool adminTransferOBO
  );

  /// @notice event when the NFT is redeemed, there are two redemption types, partial and full redemption
  /// if the remainder == 0 then it is a full redemption and the NFT is burned, otherwise it is a partial redemption
  event PlanTokensUnlocked(uint256 indexed id, uint256 unlockedAmount, uint256 planRemainder, uint256 resetDate);

  event PlanRevoked(uint256 indexed id, uint256 unlockedAmount, uint256 revokedAmount);

  event VestingPlanAdminChanged(uint256 indexed id, address _newVestingAdmin);

  event PlanTransferredByVestingAdmin(uint256 indexed id, address indexed from, address indexed to);

  function changeVestingPlanAdmin(uint256 planId, address newVestingAdmin) external {
    Plan storage plan = plans[planId];
    require(msg.sender == plan.vestingAdmin, '!vestingAdmin');
    plan.vestingAdmin = newVestingAdmin;
    emit VestingPlanAdminChanged(planId, newVestingAdmin);
  }

  function planBalanceOf(
    uint256 planId,
    uint256 timeStamp,
    uint256 redemptionTime
  ) public view returns (uint256 balance, uint256 remainder, uint256 latestUnlock) {
    Plan memory plan = plans[planId];
    (balance, remainder, latestUnlock) = TimelockLibrary.balanceAtTime(
      plan.start,
      plan.cliff,
      plan.amount,
      plan.rate,
      plan.period,
      timeStamp,
      redemptionTime
    );
  }

  /// @dev function to calculate the end date in seconds of a given unlock timelock
  /// @param planId is the NFT token ID
  function planEnd(uint256 planId) public view returns (uint256 end) {
    Plan memory plan = plans[planId];
    end = TimelockLibrary.endDate(plan.start, plan.amount, plan.rate, plan.period);
  }
}