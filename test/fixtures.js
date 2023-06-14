const { ethers } = require('hardhat');
const C = require('./constants');
const { time } = require('@nomicfoundation/hardhat-network-helpers');

const setup = async () => {
    const [admin, a, b, c, d] = await ethers.getSigners();
    const Locked = await ethers.getContractFactory('TokenLockupPlans');
    const locked = await Locked.deploy('TimeLock', 'TL');
    const VoteLocked = await ethers.getContractFactory('VotingTokenLockupPlans');
    const voteLocked = await VoteLocked.deploy('TimeLock', 'TL');
    const Vest = await ethers.getContractFactory('TokenVestingPlans');
    const vest = await Vest.deploy('TimeLock', 'TL');
    const VoteVest = await ethers.getContractFactory('VotingTokenVestingPlans');
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


module.exports = {
    setup
}