const { ethers } = require('hardhat');
const C = require('./constants');
const { time } = require('@nomicfoundation/hardhat-network-helpers');

module.exports = async (voting, vesting) => {
    const [admin, a, b, c, d] = await ethers.getSigners();
    const Locked = await ethers.getContractFactory('TimeLockedTokenPlans');
    const VoteLocked = await ethers.getContractFactory('TimeLockedVotingTokenPlans');
    const Vest = await ethers.getContractFactory('TimeVestingTokenPlans');
    const VoteVest = await ethers.getContractFactory('TimeVestingVotingTokenPlans');
    const Token = await ethers.getContractFactory('Token');
    const token = await Token.deploy(C.E18_1000000, 'Token', 'TK');
    let hedgey;
    if (voting) {
        if (vesting) {
            hedgey = await VoteVest.deploy('TimeLock', 'TL');
        } else {
            hedgey = await VoteLocked.deploy('TimeLock', 'TL');
        }
    } else {
        if (vesting) {
            hedgey = await Vest.deploy('TimeLock', 'TL');
        } else {
            hedgey = await Locked.deploy('TimeLock', 'TL');
        }
    }
    await token.approve(hedgey.address, C.E18_1000000);
    await token.approve(hedgey.address, C.E18_1000000);
    return {
        admin,
        a,
        b,
        c,
        d,
        hedgey,
        token,
    }
}