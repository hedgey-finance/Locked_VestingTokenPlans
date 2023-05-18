const { expect } = require('chai');
const setup = require('../fixtures');
const { time } = require('@nomicfoundation/hardhat-network-helpers');
const C = require('../constants');
const { BigNumber } = require('ethers');
const { ethers } = require('hardhat');

module.exports = (vesting, params) => {
  let s, admin, a, b, c, d, hedgey, batcher, token;
  let amounts, cliffs, unlockDate, total;
  it(`Mints a cliff ${vesting ? 'vesting' : 'locked'} token NFT`, async () => {
    s = await setup();
    hedgey = vesting ? s.cv : s.cl;
    admin = s.admin;
    a = s.a;
    b = s.b;
    c = s.c;
    d = s.d;
    batcher = s.batcher;
    token = s.token;
    let now = await time.latest();
    amounts = params.amounts;
    total = C.ZERO;
    params.amounts.forEach((amount) => {
      total = total.add(amount);
    });
    unlockDate = params.unlockShift + now;
    cliffs = [];
    params.timeShifts.forEach((timeShift) => {
      cliffs.push(now + timeShift);
    });
    if (vesting) {
      expect(await hedgey.createNFT(a.address, token.address, amounts, cliffs, admin.address))
        .to.emit('NFTCreated')
        .withArgs('1', a.address, token.address, amounts, cliffs, admin.address, '0');
    } else {
      expect(await hedgey.createNFT(a.address, token.address, amounts, cliffs))
        .to.emit('NFTCreated')
        .withArgs('1', a.address, token.address, amounts, cliffs);
    }
    let timelock = await hedgey.timelocks('1');
    expect(timelock.token).to.eq(token.address);
    expect(timelock.remainder).to.eq(total);
    expect(timelock.remainingCliffs).to.eq(cliffs.length);
    for (let i = 0; i < cliffs.length; i++) {
      let cliff = await hedgey.cliffs('1', i);
      expect(cliff.amount).to.eq(amounts[i]);
      expect(cliff.unlock).to.eq(cliffs[i]);
    }
  });
  it('redeems the entire NFT', async () => {
    await time.increase(params.timeShifts[0] + 1);
    await hedgey.connect(a).redeemNFTs(['1']);
  });
  it(`mints a token on the v2 contract with ${vesting ? 'vesting' : 'locked'}`, async () => {
    let v2 = s.v2;
    let firstCliff = C.E18_1000;
    let cliffAmt = C.E18_100;
    let total = cliffAmt.mul(cliffs.length - 1).add(firstCliff);
    expect(await v2.createNFT(a.address, token.address, firstCliff, cliffAmt, cliffs))
      .to.emit('NFTCreated')
      .withArgs('1', a.address, token.address, total, firstCliff, cliffAmt, cliffs.length);
    await v2.connect(a).redeemNFT('1', cliffs.length);
  });
  it('mints a streamvesting token', async () => {
    let streamer = s.streamer;
    let now = await time.latest();
    await streamer.createNFT(a.address, token.address, C.E18_1000, now, now, C.E18_1, admin.address);
  })
};
