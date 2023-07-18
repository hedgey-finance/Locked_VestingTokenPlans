const { expect } = require('chai');
const setup = require('../fixtures');
const { time } = require('@nomicfoundation/hardhat-network-helpers');
const C = require('../constants');
const { BigNumber } = require('ethers');

module.exports = (vesting, params) => {
  let s, admin, a, b, c, d, hedgey, token, dai, usdc;
  let amount, start, cliff, period, rate, end;
  it('creates a plan which is by default self delegated', async () => {
    s = await setup();
    hedgey = vesting ? s.vest : s.locked;
    admin = s.admin;
    a = s.a;
    b = s.b;
    c = s.c;
    d = s.d;
    token = s.token;
    dai = s.dai;
    usdc = s.usdc;
    await token.approve(hedgey.address, C.E18_1000000.mul(1000));
    await dai.approve(hedgey.address, C.E18_1000000.mul(1000));
    await usdc.approve(hedgey.address, C.E18_1000000.mul(1000));
    let now = BigNumber.from(await time.latest());
    amount = params.amount;
    period = params.period;
    rate = params.rate;
    start = BigNumber.from(now).add(params.start);
    cliff = BigNumber.from(start).add(params.cliff);
    end = C.planEnd(start, amount, rate, period);
    vesting
      ? await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period, admin.address, true)
      : await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period);
    expect(await hedgey.lockedBalances(a.address, token.address)).to.eq(amount);
    expect(await hedgey.delegatedBalances(a.address, token.address)).to.eq(amount);
  });
  it('delegates the plan to another wallet', async () => {
    await hedgey.connect(a).delegate('1', b.address);
    expect(await hedgey.lockedBalances(a.address, token.address)).to.eq(amount);
    expect(await hedgey.delegatedBalances(a.address, token.address)).to.eq(0);
    expect(await hedgey.lockedBalances(b.address, token.address)).to.eq(0);
    expect(await hedgey.delegatedBalances(b.address, token.address)).to.eq(amount);
  });
  it('delegates all of ones plans with the same token to another wallet', async () => {
    vesting
      ? await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period, admin.address, true)
      : await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period);
    expect(await hedgey.lockedBalances(a.address, token.address)).to.eq(amount.mul(2));
    expect(await hedgey.delegatedBalances(a.address, token.address)).to.eq(amount);
    expect(await hedgey.lockedBalances(b.address, token.address)).to.eq(0);
    expect(await hedgey.delegatedBalances(b.address, token.address)).to.eq(amount);
    await hedgey.connect(a).delegatePlans(['1', '2'], [c.address, c.address]);
    expect(await hedgey.lockedBalances(a.address, token.address)).to.eq(amount.mul(2));
    expect(await hedgey.delegatedBalances(a.address, token.address)).to.eq(0);
    expect(await hedgey.lockedBalances(b.address, token.address)).to.eq(0);
    expect(await hedgey.delegatedBalances(b.address, token.address)).to.eq(0);
    expect(await hedgey.lockedBalances(c.address, token.address)).to.eq(0);
    expect(await hedgey.delegatedBalances(c.address, token.address)).to.eq(amount.mul(2));
  });
  it('when a token is transferred the delegates and locked balances move with it', async () => {
    vesting
      ? await hedgey.transferFrom(a.address, b.address, '1')
      : await hedgey.connect(a).transferFrom(a.address, b.address, '1');
    expect(await hedgey.lockedBalances(a.address, token.address)).to.eq(amount);
    expect(await hedgey.delegatedBalances(a.address, token.address)).to.eq(0);
    expect(await hedgey.lockedBalances(b.address, token.address)).to.eq(amount);
    expect(await hedgey.delegatedBalances(b.address, token.address)).to.eq(amount);
    expect(await hedgey.lockedBalances(c.address, token.address)).to.eq(0);
    expect(await hedgey.delegatedBalances(c.address, token.address)).to.eq(amount);
  });
  it('delegates all of its tokens to a single wallet', async () => {
    vesting
      ? await hedgey.transferFrom(a.address, b.address, '2')
      : await hedgey.connect(a).transferFrom(a.address, b.address, '2');
    await hedgey.connect(b).delegateAll(token.address, d.address);
    expect(await hedgey.lockedBalances(b.address, token.address)).to.eq(amount.mul(2));
    expect(await hedgey.delegatedBalances(b.address, token.address)).to.eq(0);
    expect(await hedgey.lockedBalances(d.address, token.address)).to.eq(0);
    expect(await hedgey.delegatedBalances(d.address, token.address)).to.eq(amount.mul(2));
  })
  it('reverts if the function caller isnt the owner', async () => {
    await expect(hedgey.connect(a).delegate('1', a.address)).to.be.revertedWith('!owner');
    await expect(hedgey.connect(a).delegatePlans(['1', '2'], [a.address, d.address])).to.be.revertedWith('!owner');
  });
  it('reverts delegating multiple tokens if the array legnths are wrong', async () => {
    await expect(hedgey.connect(b).delegatePlans(['1', '2'], [a.address])).to.be.revertedWith('array error');
  })
};
