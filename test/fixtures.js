const { ethers } = require('hardhat');
const C = require('./constants');
const { time } = require('@nomicfoundation/hardhat-network-helpers');

const setup = async () => {
    const [admin, a, b, c, d] = await ethers.getSigners();
    const Locked = await ethers.getContractFactory('TimeLockedTokenPlans');
    const locked = await Locked.deploy('TimeLock', 'TL');
    const VoteLocked = await ethers.getContractFactory('TimeLockedVotingTokenPlans');
    const voteLocked = await VoteLocked.deploy('TimeLock', 'TL');
    const Vest = await ethers.getContractFactory('TimeVestingTokenPlans');
    const vest = await Vest.deploy('TimeLock', 'TL');
    const VoteVest = await ethers.getContractFactory('TimeVestingVotingTokenPlans');
    const voteVest = await VoteVest.deploy('TimeLock', 'TL');
    const BatchPlanner = await ethers.getContractFactory('BatchPlanner');
    const batcher = await BatchPlanner.deploy();
    const Token = await ethers.getContractFactory('Token');
    const token = await Token.deploy(C.E18_1000000.mul(1000), 'Token', 'TK');
    return {
        admin,
        a,
        b,
        c,
        d,
        locked,
        voteLocked,
        vest,
        voteVest,
        batcher,
        token,
    }
}

const setupLinear = async () => {
    const [admin, a, b, c, d] = await ethers.getSigners();
    const Streamer = await ethers.getContractFactory('StreamingNFT');
    const Vester = await ethers.getContractFactory('StreamVestingNFT');
    const BatchVester = await ethers.getContractFactory('BatchVester');
    const batchVester = await BatchVester.deploy();
    const streamer = await Streamer.deploy('Streamers', 'STMY');
    const vester = await Vester.deploy('Vester', 'VST', streamer.address, streamer.address);
    const Token = await ethers.getContractFactory('Token');
    const token = await Token.deploy(C.E18_1000000, 'Token', 'TK');
    return {
        admin,
        a,
        b,
        c,
        d,
        streamer,
        vester,
        batchVester,
        token,
    }
}

module.exports = {
    setup,
    setupLinear,
}