const { ethers } = require('hardhat');
const C = require('./constants');
const { time } = require('@nomicfoundation/hardhat-network-helpers');

module.exports = async () => {
    const [admin, a, b, c, d] = await ethers.getSigners();
    const CliffLock = await ethers.getContractFactory('HedgeyCliffLocks');
    const CliffVest = await ethers.getContractFactory('HedgeyCliffVesting');
    const MasterBatcher = await ethers.getContractFactory('MasterBatcher');
    const V2 = await ethers.getContractFactory('HedgeyCliffLocksV2');
    const Streamer = await ethers.getContractFactory('StreamVestingNFT');
    const Token = await ethers.getContractFactory('Token');
    const cl = await CliffLock.deploy('CliffLockedHedgeys', 'CLHD');
    const cv = await CliffVest.deploy('CliffVestingHedgeys', 'CVHD', cl.address);
    const v2 = await V2.deploy('CliffV2', 'CV2');
    const batcher = await MasterBatcher.deploy();
    const streamer = await Streamer.deploy('Streamer', 'STMY', cl.address, cl.address);
    const token = await Token.deploy(C.E18_1000000, 'Token', 'TK');
    await token.approve(cl.address, C.E18_1000000);
    await token.approve(cv.address, C.E18_1000000);
    await token.approve(batcher.address, C.E18_1000000);
    await token.approve(v2.address, C.E18_1000000);
    await token.approve(streamer.address, C.E18_1000000);
    return {
        admin,
        a,
        b,
        c,
        d,
        cl,
        cv,
        batcher,
        token,
        v2,
        streamer,
    }
}