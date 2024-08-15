# Token Lockup and Vesting Plans

Token Lockup and Vesting Plans are the backbone contracts for supporting responsible token allocations to investors, employees and contributors. This repository contains the smart contracts (EVM compatible) that are used by Hedgey to bring the products to life.  

The plans lock up ERC20 tokens, and then mint a recipient an ERC721 token to represent their right to unlock those tokens based on time vesting and time unlocking. The schedule of vesting and unlocking is linear, but periodic. Periods are based on seconds, and so may be per second unlocking, or can unlock each day, week, or any number of periodic frequency based on the same number of seconds. 

Plan features include the ability to add a start date to begin the unlocking / vesting process, back or future dated, as well as a cliff date for when the first chunk of tokens may be redeemed. 

Vesting Plans have a Vesting Admin that is responsible for revoking and plans distributed to a beneficiary, should they cut ties, for example if an employee leaves a company. 
Lockup plans are not revokable, but are by default transferable. 

The plans super powers include: 
  - the ability to partially redeem tokens (as opposed to redeeming the entire unlocked amount)
  - Voting with locked and unvested tokens (there is a Snapshot optimized and a On-chain governance optimized contract)
  - Ability to break up lockup plans into smaller segements, and then recombine them (for sub-delegation of voting, or selling in OTC secondary markets)


## Contracts Overview
These contracts below are the set of contracts that any user will interact with, whether via user interface application or by direct smart contract interaction. 

Contracts that hold tokens owned by end users, which each amount of tokens vesting / unlocking by the beneficiary is an NFT object with the vesting / unlocking details: 

- TokenVestingPlans.sol: Vesting Plans with snapshot voting optimization
- VotingTokenVestingPlans.sol: Vesting Plans built with on-chain governance functionality
- TokenLockupPlans.sol: Lockup Plans with snapshot voting optimization (NFTs are transferable)
- VotingTokenLockupPlans.sol: Lockup Plans built with on-chain governance functionality (NFTs are transferable)
- TokenLockupPlans_Bound.sol: Lockup plans with snapshot voting optimization (NFTs are not transferable)
- VotingTokenLockupPlans_Bound.sol: Lockup plans built with on-chain governance functionality (NFTs are not transferable)

Intermediary Contracts that temporarily hold tokens or route them from creators to beneficiaries: 
- BatchPlanner.sol: Contract for creating multiple vesting or lockup plans at the same time in a large batch. A simple contract to assist with generating many NFT vesting and lockup plans in a single transaction



## CLAIM CAMPAIGN UPDATE
The Claim Campaign contract was exploited in this repository, and while updates have been pushed to resolve the exploit, the current ClaimCampaigns.sol contract is NOT audited and not in production use. It is not deployed or maintained by the Hedgey app or team. The team has replaced this contract with a newer version found elsewhere in the Hedgey Repo under DelegatedClaims. 

## AUDIT UPDATE
Contracts deployed to production match commit hash `91b4c17f0b98f99c2d38f117816cc17a040a17b2` and seen on the Contract Freeze & Production Deploy release in this repository. There were 3 subsequent audits to this contract freeze, with no critical, major, high findings. One change has been updated on the current commit hash on TokenLockupPlans.sol and VotingTokenLockupPlans.sol, related to the _combinePlans() method. The update acts as a guardrail so that the same plan cannot be combined with itself (which would burn the lockup NFT and burn the plan.) While this behavior would require the owner of a lockup plan to combine a plan with itself at the smart contract level and poses no external threat, the newest commit hash with the second release will be used for future production deployments as an additional guard rail, which as of this date June 11, 2024 there are none.

## Repository Navigation
The smart contracts are all located in the ./contracts folder. The Final End User contracts are in the ./contracts/LockupPlans and ./contracts/VestingPlans folders. The lockup plan contracts are in the LockupPlans folder, and vesting plan contracts in the VestingPlans folder. The on-chain voting optimized contracts are named with Voting in the contract name, while the snapshot optimized contracts do not contain this explicit word. 

Periphery Contracts are used in addition to the core for users to quickly create and distribute multiple plans at the same time, either by direct distribution using the BatchPlanner

The Plan contracts use some shared contracts for NFT uri admin at deployment, on-chain voting vault contract. 

The core storage for the lockup and vesting plans is in the ./contracts/sharedContracts/LockedStorage.sol and VestingStorage.sol files, which has the structs, mapping and events that are used throughout the primary plan contract files.  

ERC721Delegate contract is a special iteration of the ERC721Enumerable extension that enables users to delegate their NFT to another wallet, which is optimized for snapshot voting strategies. The snapshot optimized contracts inherit the ERC721Delegate, while the on-chain voting contracts inherit the ERC721Enumerable for gas savings and efficiencies. 

There are technical documentation in this repository in the technical documentation folder that describe the contracts functions and uses, and technical requirements. For more information please visit [Hedgey Website](https://hedgey.finance)


## Testing
Clone repository

``` bash
npm install
npx hardhat compile
npx hardhat test
```

## Deployment
To deploy the contracts you should create a .env file, and add your private keys, network rpc URL, and etherscan API Key. Update the deploy.js file in the /scripts folder to deploy the desired contracts, and update the constructor argument parameters with the desired ERC721 Collection Name and Symbol. The deploy script will deploy and verify all of the files in a single function call, for a given network that supports the automated hardhat verification step. 

``` bash
npx hardhat run scripts/deploy.js --network <network-name>
```

## Testnet Deployments
# Sepolia Network:   
TokenVestingPlans: `0x68b6986416c7A38F630cBc644a2833A0b78b3631`  
VotingTokenVestingPlans: `0x8345Cfc7eB639a9178FA9e5FfdeBB62CCF5846A3`

TokenLockupPlans: `0xb49d0CD3D5290adb4aF1eBA7A6B90CdE8B9265ff`  
VotingTokenLockupPlans: `0xB82b292C9e33154636fe8839fDb6d4081Da5c359`  

TokenLockupPlans_Bound: `0xD7E7ba882a4533eC8C8C9fB933703a42627D4deA`  
VotingTokenLockupPlans_Bound: `0x2cE4DC254a4B48824e084791147Ff7220F1A08a7`  

BatchPlanner: `0xd8B085f666299E52f24e637aB1076ba5C2c38045`  
 


## Mainnet Deployments

The following networks have been deployed to mainnet contracts, at the same address for each network:   
- Ethereum Mainnet  
- ArbitrumOne  
- Optimism
- Celo  
- Polygon  
- Fantom (Opera)  
- Avalanche C-Chain  
- Gnosis Chain
- BASE
- Mantle
- Aurora
- Binance Smart Chain (BSC)
- Harmony One
- Evmos
- OEC (OkEx Chain)
- Palm Network
- Public Goods Network (PGN)  
- Linea Mainnet  
- Shimmer EVM
- Polygon zkEVM

TokenVestingPlans: `0x2CDE9919e81b20B4B33DD562a48a84b54C48F00C`

VotingTokenVestingPlans: `0x1bb64AF7FE05fc69c740609267d2AbE3e119Ef82`

TokenLockupPlans: `0x1961A23409CA59EEDCA6a99c97E4087DaD752486`

VotingTokenLockupPlans: `0x73cD8626b3cD47B009E68380720CFE6679A3Ec3D`

Bound-TokenLockupPlans: `0xA600EC7Db69DFCD21f19face5B209a55EAb7a7C0`

Bound-VotingTokenLockupPlans: `0xdE8465D44eBfC761Ee3525740E06C916886E1aEB`

BatchPlanner: `0x3466EB008EDD8d5052446293D1a7D212cb65C646`





Other Network addresses:      

- Viction Chain
- SwissDLT
- Mode Network
- Scroll   
- Flare Network
- Fraxtal  
- Zora 
- Kava Network
- Immutable zkEVM
- IOTA EVM
- Filecoin EVM


TokenVestingPlans: `0x2CDE9919e81b20B4B33DD562a48a84b54C48F00C`

VotingTokenVestingPlans: `0x1bb64AF7FE05fc69c740609267d2AbE3e119Ef82`

TokenLockupPlans: `0x1961A23409CA59EEDCA6a99c97E4087DaD752486`

VotingTokenLockupPlans: `0xA600EC7Db69DFCD21f19face5B209a55EAb7a7C0`

Bound-TokenLockupPlans: `0x06B6D0AbD9dfC7F04F478B089FD89d4107723264`

Bound-VotingTokenLockupPlans: `0x38E74A3DA3bd27dd581d5948ba19F0f684a5272f`

BatchPlanner: `0x5D3513EB3f889C8451BB8a1a02C23aFfD0CA64bE`

 



zkSync Era Mainnet:    

TokenVestingPlans: `0x04d3b05BBACe50d6627139d55B1793E2c03C53F0`

VotingTokenVestingPlans: `0xa824f42d4B6b3C51ab24dFdb268C232216a2D691`

TokenLockupPlans: `0x1e290Ad7efc6E9102eCDB3D85dAB0e8e10cA690f`

VotingTokenLockupPlans: `0x815a28bB9A5ea36C03Bc6B21072fb4e99D66b6f4`

Bound-TokenLockupPlans: `0xa83DFE7365A250faB1c3e10451676Af5DEF36E08`

Bound-VotingTokenLockupPlans: `0xc7EEFF556C4999169E96195b4091669C1ecA5C23`

BatchPlanner: `0x0d3F97b0f3027abbDdf21792fFcA34eAd23c02eF`

  



  
