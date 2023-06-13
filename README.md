# Locked_VestingTokenPlans

Locked and Vesting Token Plans are the backbone contracts for supporting responsible token allocations to investors, employees and contributors. This repository contains the smart contracts (EVM compatible) that are used by Hedgey to bring the products to life.  

The plans lock up ERC20 tokens, and then mint a recipient an ERC721 token to represent their right to unlock those tokens based on time vesting and time unlocking. The schedule of vesting and unlocking is linear, but periodic. Periods are based on seconds, and so may be per second unlocking, or can unlock each day, week, or any number of periodic frequency based on the same number of seconds. 

Plan features include the ability to add a start date to begin the unlocking / vesting process, back or future dated, as well as a cliff date for when the first chunk of tokens may be redeemed. 

Vesting Plans have a Vesting Admin that is responsible for revoking and plans distributed to a beneficiary, should they cut ties, for example if an employee leaves a company. 
Lockup plans are not revokable, but are by default transferable. 

The plans super powers include: 
  - the ability to partially redeem tokens (as opposed to redeeming the entire unlocked amount)
  - Voting with locked and unvested tokens (there is a Snapshot optimized and a On-chain governance optimized contract)
  - Ability to break up lockup plans into smaller segements, and then recombine them (for sub-delegation of voting, or selling in OTC secondary markets)


There are technical documentation in this repository that describe the contracts functions and uses, and technical requirements. For more information please visit [Hedgey Website](https://hedgey.finance)

## Testing
Clone repository

``` bash
npm install
npx hardhat compile
npx hardhat test
```

## Deployment
To deploy the contracts you should create a .env file, and add your private keys, network rpc URL, and etherscan API Key. Update the deploy.js file in the /scripts folder to deploy the desired contracts, and update the constructor argument parameters with the desired ERC721 Collection Name and Symbol. Then you can run in the terminal the hardhat deployer (note it doesn't work for all networks, some EVMs are not supported by hardhat).

``` bash
npx hardhat run scripts/deploy.js --network <network-name>
```

## Testnet Deployments


## Mainnet Deployments