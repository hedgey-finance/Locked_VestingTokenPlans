const { expect } = require('chai');
const setup = require('../fixtures');
const { time } = require('@nomicfoundation/hardhat-network-helpers');
const C = require('../constants');
const { BigNumber } = require('ethers');

const redeemTests = (vesting, voting, params) => {
  let s, admin, a, b, c, d, hedgey, token, batcher;
  let amount, start, cliff, period, rate, end;
  it(`it mints a ${vesting ? 'vesting' : 'lockup'} plan, and confirms various balance checks`, async () => {
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
    batcher = s.batcher;
    await token.approve(batcher.address, C.E18_1000000);
    await token.approve(hedgey.address, C.E18_1000000);
    let now = await time.latest();
    amount = params.amount;
    period = params.period;
    rate = params.rate;
    start = BigNumber.from(now).add(params.start);
    cliff = BigNumber.from(start).add(params.cliff);
    end = C.planEnd(start, amount, rate, period);
    vesting
      ? await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period, admin.address, true)
      : await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period);
    let planId = '1';
    expect(await hedgey.planEnd(planId)).to.eq(end);
    now = await time.latest();
    // check time for one period from start, two periods from start, cliff date, one period after cliff, two periods after cliff, end date
    let check = start.add(period);
    let checkNow = await hedgey.planBalanceOf(planId, now, check);
    let _checkNow = C.balanceAtTime(start, cliff, amount, rate, period, now, check);
    expect(checkNow.balance).to.eq(_checkNow.balance);
    expect(checkNow.remainder).to.eq(_checkNow.remainder);
    expect(checkNow.latestUnlock).to.eq(_checkNow.latestUnlock);

    checkNow = await hedgey.planBalanceOf(planId, check, check.sub(period));
    _checkNow = C.balanceAtTime(start, cliff, amount, rate, period, check, check.sub(period));
    expect(checkNow.balance).to.eq(_checkNow.balance);
    expect(checkNow.remainder).to.eq(_checkNow.remainder);
    expect(checkNow.latestUnlock).to.eq(_checkNow.latestUnlock);

    checkNow = await hedgey.planBalanceOf(planId, check, check);
    _checkNow = C.balanceAtTime(start, cliff, amount, rate, period, check, check);
    expect(checkNow.balance).to.eq(_checkNow.balance);
    expect(checkNow.remainder).to.eq(_checkNow.remainder);
    expect(checkNow.latestUnlock).to.eq(_checkNow.latestUnlock);

    check = cliff;
    checkNow = await hedgey.planBalanceOf(planId, now, check);
    _checkNow = C.balanceAtTime(start, cliff, amount, rate, period, now, check);
    expect(checkNow.balance).to.eq(_checkNow.balance);
    expect(checkNow.remainder).to.eq(_checkNow.remainder);
    expect(checkNow.latestUnlock).to.eq(_checkNow.latestUnlock);

    checkNow = await hedgey.planBalanceOf(planId, check, check.sub(period));
    _checkNow = C.balanceAtTime(start, cliff, amount, rate, period, check, check.sub(period));
    expect(checkNow.balance).to.eq(_checkNow.balance);
    expect(checkNow.remainder).to.eq(_checkNow.remainder);
    expect(checkNow.latestUnlock).to.eq(_checkNow.latestUnlock);

    checkNow = await hedgey.planBalanceOf(planId, check, check);
    _checkNow = C.balanceAtTime(start, cliff, amount, rate, period, check, check);
    expect(checkNow.balance).to.eq(_checkNow.balance);
    expect(checkNow.remainder).to.eq(_checkNow.remainder);
    expect(checkNow.latestUnlock).to.eq(_checkNow.latestUnlock);

    check = cliff.add(period);
    checkNow = await hedgey.planBalanceOf(planId, now, check);
    _checkNow = C.balanceAtTime(start, cliff, amount, rate, period, now, check);
    expect(checkNow.balance).to.eq(_checkNow.balance);
    expect(checkNow.remainder).to.eq(_checkNow.remainder);
    expect(checkNow.latestUnlock).to.eq(_checkNow.latestUnlock);

    checkNow = await hedgey.planBalanceOf(planId, check, check.sub(period));
    _checkNow = C.balanceAtTime(start, cliff, amount, rate, period, check, check.sub(period));
    expect(checkNow.balance).to.eq(_checkNow.balance);
    expect(checkNow.remainder).to.eq(_checkNow.remainder);
    expect(checkNow.latestUnlock).to.eq(_checkNow.latestUnlock);

    checkNow = await hedgey.planBalanceOf(planId, check, check);
    _checkNow = C.balanceAtTime(start, cliff, amount, rate, period, check, check);
    expect(checkNow.balance).to.eq(_checkNow.balance);
    expect(checkNow.remainder).to.eq(_checkNow.remainder);
    expect(checkNow.latestUnlock).to.eq(_checkNow.latestUnlock);

    check = check.add(period);
    checkNow = await hedgey.planBalanceOf(planId, now, check);
    _checkNow = C.balanceAtTime(start, cliff, amount, rate, period, now, check);
    expect(checkNow.balance).to.eq(_checkNow.balance);
    expect(checkNow.remainder).to.eq(_checkNow.remainder);
    expect(checkNow.latestUnlock).to.eq(_checkNow.latestUnlock);

    checkNow = await hedgey.planBalanceOf(planId, check, check.sub(period));
    _checkNow = C.balanceAtTime(start, cliff, amount, rate, period, check, check.sub(period));
    expect(checkNow.balance).to.eq(_checkNow.balance);
    expect(checkNow.remainder).to.eq(_checkNow.remainder);
    expect(checkNow.latestUnlock).to.eq(_checkNow.latestUnlock);

    checkNow = await hedgey.planBalanceOf(planId, check, check);
    _checkNow = C.balanceAtTime(start, cliff, amount, rate, period, check, check);
    expect(checkNow.balance).to.eq(_checkNow.balance);
    expect(checkNow.remainder).to.eq(_checkNow.remainder);
    expect(checkNow.latestUnlock).to.eq(_checkNow.latestUnlock);

    check = end;
    checkNow = await hedgey.planBalanceOf(planId, now, check);
    _checkNow = C.balanceAtTime(start, cliff, amount, rate, period, now, check);
    expect(checkNow.balance).to.eq(_checkNow.balance);
    expect(checkNow.remainder).to.eq(_checkNow.remainder);
    expect(checkNow.latestUnlock).to.eq(_checkNow.latestUnlock);

    checkNow = await hedgey.planBalanceOf(planId, check, check.sub(period));
    _checkNow = C.balanceAtTime(start, cliff, amount, rate, period, check, check.sub(period));
    expect(checkNow.balance).to.eq(_checkNow.balance);
    expect(checkNow.remainder).to.eq(_checkNow.remainder);
    expect(checkNow.latestUnlock).to.eq(_checkNow.latestUnlock);

    checkNow = await hedgey.planBalanceOf(planId, check, check);
    _checkNow = C.balanceAtTime(start, cliff, amount, rate, period, check, check);
    expect(checkNow.balance).to.eq(_checkNow.balance);
    expect(checkNow.remainder).to.eq(_checkNow.remainder);
    expect(checkNow.latestUnlock).to.eq(_checkNow.latestUnlock);
  });
  it('redeems a single plan with multiple partial redemptions', async () => {
    let difference = cliff.add(period).sub(await time.latest());
    let redemptionTime = BigNumber.from(await time.increase(difference));
    let now = await time.latest();
    let t_0 = redemptionTime;
    let cb = C.balanceAtTime(start, cliff, amount, rate, period, now, redemptionTime);
    let tx = await hedgey.connect(a).partialRedeemPlans(['1'], redemptionTime);
    expect(tx).to.emit('PlanRedeemed').withArgs('1', cb.balance, cb.remainder, cb.latestUnlock);
    expect(await token.balanceOf(hedgey.address)).to.eq(amount.sub(cb.balance));
    expect(await token.balanceOf(a.address)).to.eq(cb.balance);
    now = await time.increase(period.mul(3));
    redemptionTime = BigNumber.from(now).sub(period);
    let periods = redemptionTime.sub(t_0).div(period);
    const preBalance = await token.balanceOf(a.address);
    expect((await hedgey.planBalanceOf('1', now, redemptionTime)).balance).to.eq(periods.mul(rate));
    expect(await hedgey.connect(a).partialRedeemPlans(['1'], redemptionTime))
      .to.emit('PlanRedeemed')
      .withArgs('1', cb.balance, cb.remainder, cb.latestUnlock);
    expect(await token.balanceOf(a.address)).to.eq(preBalance.add(periods.mul(rate)));
    expect(await token.balanceOf(hedgey.address)).to.eq(amount.sub(preBalance.add(periods.mul(rate))));

    difference = end.sub(now);
    await time.increase(difference.add(period));
    expect(await hedgey.connect(a).partialRedeemPlans(['1'], end))
      .to.emit('PlanRedeemed')
      .withArgs('1', cb.remainder, 0, end);
    expect(await token.balanceOf(a.address)).to.eq(amount);
    expect(await token.balanceOf(hedgey.address)).to.eq(0);
    expect(await hedgey.balanceOf(a.address)).to.eq(0);
    await expect(hedgey.ownerOf('1')).to.be.reverted;
  });
  it('redeems multiple plans with multiple partial redemptions', async () => {
    let now = await time.latest();
    start = BigNumber.from(now).add(params.start);
    cliff = BigNumber.from(start).add(params.cliff);
    let singlePlan = {
      recipient: b.address,
      amount,
      start,
      cliff,
      rate,
    };
    const batchSize = 5;
    let totalAmount = amount.mul(batchSize);
    let batch = Array(batchSize).fill(singlePlan);
    let tx = vesting
      ? await batcher.batchVestingPlans(
          hedgey.address,
          token.address,
          totalAmount,
          batch,
          period,
          admin.address,
          true,
          '0'
        )
      : await batcher.batchLockingPlans(hedgey.address, token.address, totalAmount, batch, period, '0');
    // plans 2 - 6
    now = await time.increase(params.cliff.add(period));
    const partial = C.balanceAtTime(start, cliff, amount, rate, period, now, cliff).balance;
    const periods = cliff.sub(start).div(period);
    let redeemTx = await hedgey.connect(b).partialRedeemPlans(['2', '3', '4', '5', '6'], cliff);
    expect(await token.balanceOf(b.address)).to.eq(partial.mul(5));
    expect(await token.balanceOf(b.address)).to.eq(periods.mul(rate).mul(5));
  });
  it('redeems muliple partials, skipping one that had previously been redeemed', async () => {
    // previous 5 have been redeemed at cliff - move forward to 3 periods and redeem number 3
    now = await time.increase(period.mul(3));
    let tx = await hedgey.connect(b).partialRedeemPlans(['3'], now);
    const amountRedeemed = (await tx.wait()).events[1].args.amountRedeemed;
    let bal = await token.balanceOf(b.address);
    const plan3 = await hedgey.plans('3');
    await hedgey.connect(b).partialRedeemPlans(['2', '3', '4', '5', '6'], now);
    const _plan3 = await hedgey.plans('3');
    expect(plan3.amount).to.eq(_plan3.amount);
    expect(plan3.start).to.eq(_plan3.start);
  });
  it('redeems a single plan with multiple normal redemptions', async () => {
    // each balance check assumes 1 second of time increase between calculating and processing block
    let now = await time.latest();
    start = BigNumber.from(now).add(params.start);
    cliff = BigNumber.from(start).add(params.cliff);
    vesting
      ? await hedgey.createPlan(c.address, token.address, amount, start, cliff, rate, period, admin.address, true)
      : await hedgey.createPlan(c.address, token.address, amount, start, cliff, rate, period);
    // redeem pre cliff - nothing should redeem
    await hedgey.connect(c).redeemPlans(['7']);
    expect(await token.balanceOf(c.address)).to.eq(0);;
    await time.increase(cliff.sub(now));
    now = BigNumber.from(await time.latest())
    let check = C.balanceAtTime(start, cliff, amount, rate, period, now.add(1), now.add(1));
    expect(await hedgey.connect(c).redeemPlans(['7']))
      .to.emit('PlanRedeemed')
      .withArgs('7', check.balance, check.remainder, check.latestUnlock);
    expect(await token.balanceOf(c.address)).to.eq(check.balance);
  });
  //   it('redeems multiple plans with multiple normal redemptions', async () => {});
  //   it('redeems one plan with the redeemAll redemption', async () => {});
  //   it('redeems multiple plans with the redeemAll redemption', async () => {});
  //   it('redeems a partial, then a normal, and then an all redemption', async () => {});
  //   it('redeems partial and normal on segmented plans', async () => {});
  //   it('redeems partial and normal on combined plans', async () => {});
  //   it('transfers a plan and new owner redeems', async () => {});
};

const redeemErrorTests = (vesting, voting) => {
  let s, admin, a, b, c, d, hedgey, token;
  let amount, start, cliff, period, rate, end;
  it('reverts if the redeemer is not the owner of the plan', async () => {});
  it('gets skipped and does not redeem if the redemption time is before the start', async () => {});
  it('partial reverts if the redemption time requested is in the fuutre', async () => {});
  it('is skipped if the redemption time is before the cliff', async () => {});
};

module.exports = {
  redeemTests,
  redeemErrorTests,
};
