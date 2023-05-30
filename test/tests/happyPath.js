const { expect } = require('chai');
const setup = require('../fixtures');
const { time } = require('@nomicfoundation/hardhat-network-helpers');
const C = require('../constants');
const { BigNumber } = require('ethers');
const { ethers } = require('hardhat');

module.exports = (vesting, params) => {
  let s, admin, a, b, c, d, hedgey, token;
  let amount, start, cliff, interval, rate, unlockDate, end;
  it(`Mints a cliff ${vesting ? 'vesting' : 'locked'} token NFT`, async () => {
    s = await setup();
    hedgey = s.tl;
    admin = s.admin;
    a = s.a;
    b = s.b;
    c = s.c;
    d = s.d;
    token = s.token;
    let now = await time.latest();
    amount = params.amount;
    interval = params.interval;
    rate = params.rate;
    start = params.start + now;
    unlockDate = params.unlock + now;
    cliff = params.cliff + now;
    expect(await hedgey.createNFT(a.address, token.address, amount, start, cliff, rate, interval))
      .to.emit('NFTCreated')
      .withArgs('1', a.address, token.address, amount, start, cliff, rate, interval);
  });
  it('mints on the streamer version', async () => {
    let streamer = s.streamer;
    await streamer.createNFT(a.address, token.address, amount, start, cliff, rate);
  });
  it('mints an nft on the vesting nft', async () => {
    let vesting = s.vester;
    await vesting.createNFT(a.address, token.address, amount, start, cliff, rate, admin.address);
  })
};
