const { expect } = require('chai');
const { setup, setupLinear }  = require('../fixtures');
const { time } = require('@nomicfoundation/hardhat-network-helpers');
const C = require('../constants');
const { BigNumber } = require('ethers');
const { ethers } = require('hardhat');

module.exports = (vesting, voting, params) => {
  let s, admin, a, b, c, d, hedgey, token;
  let amount, start, cliff, period, rate, end;
  it(`Creates a ${vesting ? 'vesting' : 'locked'} ${voting ? 'voting' : 'not voting'} token plan`, async () => {
    s = await setup();
    if (vesting && voting) hedgey = s.voteVest;
    else if (!vesting && voting) hedgey = s.voteLocked;
    else if (vesting && !voting) hedgey = s.vest;
    else hedgey = s.locked;
    admin = s.admin;
    a = s.a;
    b = s.b;
    c = s.c;
    d = s.d;
    token = s.token;
    await token.approve(hedgey.address, C.E18_1000000);
    let now = await time.latest();
    amount = params.amount;
    period = params.period;
    rate = params.rate;
    start = params.start + now;
    cliff = params.cliff + now;
    end = C.planEnd(start, amount, rate, period);
    if (vesting) {
      expect(await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period, admin.address, false))
        .to.emit('PlanCreated')
        .withArgs('1', a.address, token.address, amount, start, cliff, end, rate, period, admin.address, false);
    } else {
      expect(await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period))
        .to.emit('PlanCreated')
        .withArgs('1', a.address, token.address, amount, start, cliff, end, rate, period);
    }
    expect(await token.balanceOf(hedgey.address)).to.eq(amount);
    expect(await hedgey.ownerOf('1')).to.eq(a.address);
    expect(await hedgey.balanceOf(a.address)).to.eq(1);
    const plan = await hedgey.plans('1');
    expect(plan.token).to.eq(token.address);
    expect(plan.amount).to.eq(amount);
    expect(plan.start).to.eq(start);
    expect(plan.rate).to.eq(rate);
    expect(plan.period).to.eq(period);
    expect(plan.cliff).to.eq(cliff);
    if (vesting) expect(plan.vestingAdmin).to.eq(admin.address);
    expect(await hedgey.lockedBalances(a.address, token.address)).to.eq(amount);
  });
  it('checks the balances for accuracy', async () => {
    //write tests for checking the balance accuracy here:  

  })
  it(`batch creates several ${vesting ? 'vesting' : 'lockup'} ${voting ? 'voting' : 'not voting'} plans`, async () => {
    const batcher = s.batcher;
    await token.approve(batcher.address, C.E18_1000000);
    let singlePlan = {
      recipient: a.address,
      amount,
      start,
      cliff,
      rate
    }
    const batchSize = 80;
    let totalAmount = amount.mul(batchSize);
    let batch = Array(batchSize).fill(singlePlan);
    if (vesting) {
      await batcher.batchVestingPlans(hedgey.address, token.address, totalAmount, batch, period, admin.address);
    } else {
      await batcher.batchLockingPlans(hedgey.address, token.address, totalAmount, batch, period);
    }
  });
};
