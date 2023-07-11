const { ethers } = require("hardhat");

async function deployNFTContract(artifact, args, uriBase) {
    const Contract = await ethers.getContractFactory(artifact);
    const contract = await Contract.deploy(...args);
    await contract.deployed();
    console.log(`new contract deployed to ${contract.address}`);
    let uri = `${uriBase}${contract.address.toLocaleLowerCase()}/`;
    const tx = await contract.updateBaseURI(uri);
    console.log(`base URI tx hash: ${tx.hash}`);
}

async function deployPeriphery(donationAddress) {
    // const Planner = await ethers.getContractFactory('BatchPlanner');
    // const planner = await Planner.deploy();
    // await planner.deployed();
    // console.log(`new planner deployed to ${planner.address}`);
    const Claimer = await ethers.getContractFactory('ClaimCampaigns');
    const claimer = await Claimer.deploy(donationAddress);
    await claimer.deployed();
    console.log(`new claimer deployed to ${claimer.address}`);
}

const donationAddress = '';
//deployPeriphery(donationAddress);