const { ethers, run } = require('hardhat');
const { setTimeout } = require("timers/promises");

async function deployNFTContract(artifact, args, uriBase) {
  const Contract = await ethers.getContractFactory(artifact);
  const contract = await Contract.deploy(...args);
  await contract.deployed();
  console.log(`new ${artifact} contract deployed to ${contract.address}`);
  let uri = `${uriBase}${contract.address.toLowerCase()}/`;
  const tx = await contract.updateBaseURI(uri);
  // await setTimeout(10000)
  // await run("verify:verify", {
  //   address: contract.address,
  //   constructorArguments: args,
  // });
  return {
    address: contract.address,
    args: args,
  };
  
}

async function deployPeriphery() {
  const wallets = await ethers.getSigners();
  const wallet = wallets[1];
  const donationAddress = wallet.address;
  const Planner = await ethers.getContractFactory('BatchPlanner');
  const planner = await Planner.deploy();
  await planner.deployed();
  console.log(`new planner deployed to ${planner.address}`);
  const Claimer = await ethers.getContractFactory('ClaimCampaigns');
  const claimer = await Claimer.connect(wallet).deploy(donationAddress);
  await claimer.deployed();
  console.log(`new claimer deployed to ${claimer.address}`);
  await setTimeout(10000)
  await run("verify:verify", {
    address: claimer.address,
    constructorArguments: [donationAddress],
  });
  await run("verify:verify", {
    address: planner.address,
  });
}

async function verify(address, args) {
  await run("verify:verify", {
    address: address,
    constructorArguments: args,
  });
}

async function deployAll(artifacts, args, uri, network) {
  const verifyArgs = [];
  const uriBase = `${uri}${network}`;
  for (let i = 0; i < artifacts.length; i++) {
    let v = await deployNFTContract(artifacts[i], args[i], uriBase);
    verifyArgs.push(v);
  }
  deployPeriphery();
  for (let i = 0; i < verifyArgs.length; i++) {
    await verify(verifyArgs[i].address, verifyArgs[i].args);
  }
}

const artifacts = [
  'TokenVestingPlans',
  'VotingTokenVestingPlans',
  'TokenLockupPlans',
  'VotingTokenLockupPlans',
  'TokenLockupPlans_Bound',
  'VotingTokenLockupPlans_Bound',
];
const args = [
  ['TokenVestingPlans', 'TVP'],
  ['VotingTokenVestingPlans', 'VTVP'],
  ['TokenLockupPlans', 'TLP'],
  ['VotingTokenLockupPlans', 'VTLP'],
  ['Bound-TokenLockupPlans', 'B-TLP'],
  ['Bound-VotingTokenLockupPlans', 'B-VTLP'],
];
const uri = 'https://dynamic-nft.hedgey.finance/';
const network = 'scroll/'

deployAll(artifacts, args, uri, network);


async function updateBaseURI(artifact, address, uriBase) {
  const Contract = await ethers.getContractFactory(artifact);
  const contract = Contract.attach(address);
  let uri = `${uriBase}${address.toLowerCase()}/`;
  await contract.updateBaseURI(uri);
}

// updateBaseURI('TokenLockupPlans_Bound', '0x06B6D0AbD9dfC7F04F478B089FD89d4107723264', 'https://dynamic-nft.hedgey.finance/berachainArtio/');

