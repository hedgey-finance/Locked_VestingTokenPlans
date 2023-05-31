const { expect } = require('chai');
const setup = require('../fixtures');
const { time } = require('@nomicfoundation/hardhat-network-helpers');
const C = require('../constants');
const { BigNumber } = require('ethers');
const { ethers } = require('hardhat');

module.exports = (voting, vesting, params) => {
  let s, admin, a, b, c, d, hedgey, token;
  let amount, start, cliff, period, rate, end;
  it(`Mints a cliff ${vesting ? 'vesting' : 'locked'} ${voting ? 'voting' : 'not voting'} token plan`, async () => {
    s = await setup(voting, vesting);
    hedgey = s.hedgey;
    admin = s.admin;
    a = s.a;
    b = s.b;
    c = s.c;
    d = s.d;
    token = s.token;
    let now = await time.latest();
    amount = params.amount;
    period = params.period;
    rate = params.rate;
    start = params.start + now;
    cliff = params.cliff + now;
    end = C.planEnd(start, amount, rate, period);
    if (vesting) {
      expect(await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period, admin.address))
        .to.emit('PlanCreated')
        .withArgs('1', a.address, token.address, amount, start, cliff, end, rate, period, admin.address);
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
};
