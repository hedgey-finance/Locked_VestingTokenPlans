module.exports = {
  skipFiles: [
    'test/Token.sol',
    'test/FakeVoteToken.sol',
    'test/NonVotingToken.sol',
  ],
  configureYulOptimizer: true,
};

/**
 * 'ERC721Delegate/ERC721Delegate.sol',
    'ERC721Delegate/IERC721Delegate.sol',
    'interfaces/IDelegateNFT.sol',
    'interfaces/ILockupPlans.sol',
    'interfaces/IVestingPlans.sol',
    'libraries/TransferHelper.sol',
    'LockupPlans/NonTransferable/TokenLockupPlans_Bound',
    'LockupPlans/NonTransferable/VotingTokenLockupPlans_Bound',
    'Lockups/TokenLockupPlans.sol',
    'Lockups/VotingTokenLockupPlans.sol',
    'Periphery/BatchPlanner.sol',
    'Periphery/ClaimCampaigns.sol'
 */