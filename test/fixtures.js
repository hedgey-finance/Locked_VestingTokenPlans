const { ethers } = require('hardhat');
const C = require('./constants');
const { time } = require('@nomicfoundation/hardhat-network-helpers');

module.exports = async () => {
    const [admin, a, b, c, d] = await ethers.getSigners();
    const TL = await ethers.getContractFactory('TimeLockedNFT');
    const Streamer = await ethers.getContractFactory('StreamingNFT');
    const Vester = await ethers.getContractFactory('StreamVestingNFT');
    const Token = await ethers.getContractFactory('Token');
    const tl = await TL.deploy('TimeLockedHedgeys', 'TLHD');
    const streamer = await Streamer.deploy('StreamingHedgeys', 'STHMY');
    const vester = await Vester.deploy('Streamer', 'STMY', tl.address, streamer.address);
    const token = await Token.deploy(C.E18_1000000, 'Token', 'TK');
    await token.approve(tl.address, C.E18_1000000);
    await token.approve(vester.address, C.E18_1000000);
    await token.approve(streamer.address, C.E18_1000000);
    return {
        admin,
        a,
        b,
        c,
        d,
        tl,
        vester,
        token,
        streamer,
    }
}