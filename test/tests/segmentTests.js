const { expect } = require('chai');
const setup = require('../fixtures');
const { time } = require('@nomicfoundation/hardhat-network-helpers');
const C = require('../constants');
const { BigNumber } = require('ethers');

/**Testing the segmentPlans and combinePlans functions on the timelocked token contracts
 * 1. Need to test that the plans when segmented create a second NFT, where the amounts are segmented and rates, but all other info remains the same
 * 2. For Voting contract need to test separately creating a voting vault, then segmenting with the voting vault
 * 3. Test combining the two NFTs back together, make sure they recreate the original
 * 4. For voting need to test if one of the two NFTs have a vault, if both have a vault
 * 5. Error testing
 */

const segmentTests = (voting, params) => {
  let s, admin, a, b, c, d, hedgey, token;
  let amount, start, cliff, period, rate, end, planAmount, planRate, planEnd, segmentAmount, segmentRate, secondSegment;
  it(`mints a plan and creates a segment`, async () => {
    s = await setup();
    hedgey = voting ? s.voteLocked : s.locked;
    admin = s.admin;
    a = s.a;
    b = s.b;
    c = s.c;
    d = s.d;
    token = s.token;
    await token.approve(hedgey.address, C.E18_1000000.mul(10000));
    let now = await time.latest();
    amount = params.amount;
    period = params.period;
    rate = params.rate;
    start = BigNumber.from(now).add(params.start);
    cliff = BigNumber.from(start).add(params.cliff);
    end = C.planEnd(start, amount, rate, period);
    segmentAmount = params.segmentAmount;
    secondSegment = params.secondSegment;
    await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period);
    // now holder A will segment it into two plans
    expect(await hedgey.connect(a).segmentPlan('1', [segmentAmount])).to.emit('PlanSegmented');
    const plan1End = await hedgey.planEnd('1');
    const plan2End = await hedgey.planEnd('2');
    expect(plan1End.gte(end)).to.eq(true);
    expect(plan2End.gte(end)).to.eq(true);
    const plan1 = await hedgey.plans('1');
    const plan2 = await hedgey.plans('2');
    expect(plan1.amount.add(plan2.amount)).to.eq(amount);
    expect(plan1.cliff).to.eq(plan2.cliff);
    expect(plan1.cliff).to.eq(cliff);
    expect(plan1.start).to.eq(plan2.start);
    expect(plan1.start).to.eq(start);
    expect(plan1.period).to.eq(plan2.period);
    expect(plan1.period).to.eq(period);
    const calc1Rate = C.proratePlanRate(amount, plan1.amount, rate);
    expect(calc1Rate).to.eq(plan1.rate);
    const calc2Rate = C.calcPlanRate(plan2.amount, plan2.period, end, plan2.start, rate, plan1.rate);
    expect(calc2Rate).to.eq(plan2.rate);
    expect(await hedgey.balanceOf(a.address)).to.eq(2);
    expect(await hedgey.ownerOf('2')).to.eq(a.address);
    planAmount = plan1.amount;
    planRate = plan1.rate;
    planEnd = plan1End;
    segmentRate = plan2.rate;
  });
  it('Recombines the two segmented plans', async () => {
    const combinedRate = C.calcCombinedRate(planAmount, segmentAmount, planRate, segmentRate, start, planEnd, period);
    expect(await hedgey.connect(a).combinePlans('1', '2'))
      .to.emit('PlansCombined')
      .withArgs('1', '2', '1', amount, rate, start, cliff, period, end);
    // check details of plan 1 match original plan 1
    const plan1End = await hedgey.planEnd('1');
    expect(plan1End).to.eq(end);
    const plan1 = await hedgey.plans('1');
    expect(plan1.amount).to.eq(amount);
    expect(plan1.rate).to.eq(combinedRate);
    if (!plan1.rate.eq(rate)) {
      // if they aren't equal, lets just check the period right before the plan end
      // and ensure that only an insignificant amount of tokens vest per period
      const originalPlanBalance = C.balanceAtTime(
        start,
        cliff,
        amount,
        rate,
        period,
        end.sub(period),
        end.sub(period)
      ).balance;
      const newPlanBalance = C.balanceAtTime(
        plan1.start,
        plan1.cliff,
        plan1.amount,
        plan1.rate,
        plan1.period,
        end.sub(period),
        end.sub(period)
      ).balance;
      const newPlanEarlyRedemption = newPlanBalance.sub(originalPlanBalance).div(C.E18_1);
      // although there may be a small early redemption amount, the end date is still the same, and we simply care that thee amount is insignificant
      /// defined by us as the a single token additional / total plan periods of the original must be less than 1
      expect(newPlanEarlyRedemption.div(C.totalPeriods(rate, amount))).to.eq(0);
    }
    expect(plan1.start).to.eq(start);
    expect(plan1.cliff).to.eq(cliff);
    expect(plan1.period).to.eq(period);
    // expect plan 2 to be a dud
    const plan2 = await hedgey.plans('2');
    expect(plan2.amount).to.eq(0);
    expect(plan2.rate).to.eq(0);
    expect(plan2.start).to.eq(0);
    expect(plan2.cliff).to.eq(0);
    expect(plan2.period).to.eq(0);
    await expect(hedgey.ownerOf('2')).to.be.reverted;
    expect(await hedgey.balanceOf(a.address)).to.eq(1);
  });
  it('segments a single plan with two segments', async () => {
    await hedgey.createPlan(b.address, token.address, amount, start, cliff, rate, period);
    await hedgey.connect(b).segmentPlan('3', [segmentAmount, secondSegment]);
    // now it should be plans 3 and 4, 5
    expect(await hedgey.balanceOf(b.address)).to.eq(3);
    expect(await hedgey.ownerOf('3')).to.eq(b.address);
    expect(await hedgey.ownerOf('4')).to.eq(b.address);
    expect(await hedgey.ownerOf('5')).to.eq(b.address);
    const plan3 = await hedgey.plans('3');
    const plan4 = await hedgey.plans('4');
    const plan5 = await hedgey.plans('5');
    expect(plan3.amount).to.eq(amount.sub(segmentAmount).sub(secondSegment));
    expect(plan4.amount).to.eq(segmentAmount);
    expect(plan5.amount).to.eq(secondSegment);
    const plan3End = await hedgey.planEnd('3');
    const plan4End = await hedgey.planEnd('4');
    const plan5End = await hedgey.planEnd('5');
    expect(plan3End.gte(end)).to.eq(true);
    expect(plan4End.gte(end)).to.eq(true);
    expect(plan5End.gte(end)).to.eq(true);
    // calculation of rates as follows, plan 1 gets segmented first and then it gets segmented a second time
    let plan3FirstRate = C.proratePlanRate(amount, amount.sub(segmentAmount), rate);
    let plan3FinalRate = C.proratePlanRate(
      amount.sub(segmentAmount),
      amount.sub(segmentAmount).sub(secondSegment),
      plan3FirstRate
    );
    expect(plan3.rate).to.eq(plan3FinalRate);
    const calcPlan4Rate = C.calcPlanRate(segmentAmount, period, end, start, rate, plan3FirstRate);
    expect(plan4.rate).to.eq(calcPlan4Rate);
    const planEndIntermediate = C.planEnd(start, amount.sub(segmentAmount), plan3FirstRate, period);
    const calcPlan5Rate = C.calcPlanRate(
      secondSegment,
      period,
      planEndIntermediate,
      start,
      plan3FirstRate,
      plan3FinalRate
    );
    const combinedEnd = C.planEnd(
      start,
      plan3.amount.add(plan4.amount).add(plan5.amount),
      plan3.rate.add(plan4.rate).add(plan5.rate),
      period
    );
    expect(combinedEnd.gte(end)).to.eq(true);
    expect(plan5.rate).to.eq(calcPlan5Rate);
    expect(plan3.cliff).to.eq(cliff);
    expect(plan4.cliff).to.eq(cliff);
    expect(plan5.cliff).to.eq(cliff);
    expect(plan3.start).to.eq(start);
    expect(plan4.start).to.eq(start);
    expect(plan5.start).to.eq(start);
    expect(plan3.period).to.eq(period);
    expect(plan4.period).to.eq(period);
    expect(plan5.period).to.eq(period);
  });
  it('recombines two children segments together', async () => {
    const rate4 = (await hedgey.plans('4')).rate;
    const rate5 = (await hedgey.plans('5')).rate;
    const plan4preEnd = await hedgey.planEnd('4');
    expect(await hedgey.connect(b).combinePlans('4', '5')).to.emit('PlansCombined');
    expect(await hedgey.balanceOf(b.address)).to.eq(2);
    await expect(hedgey.ownerOf('5')).to.be.reverted;
    const plan5 = await hedgey.plans('5');
    expect(plan5.amount).to.eq(0);
    expect(plan5.rate).to.eq(0);
    expect(plan5.start).to.eq(0);
    expect(plan5.cliff).to.eq(0);
    expect(plan5.period).to.eq(0);
    const plan4 = await hedgey.plans('4');
    expect(plan4.amount).to.eq(segmentAmount.add(secondSegment));
    expect(plan4.start).to.eq(start);
    expect(plan4.cliff).to.eq(cliff);
    expect(plan4.period).to.eq(period);
    const calcPlan4Rate = C.calcCombinedRate(segmentAmount, secondSegment, rate4, rate5, start, plan4preEnd, period);
    expect(plan4.rate).to.eq(calcPlan4Rate);
    expect(await hedgey.planEnd('4')).to.eq(plan4preEnd);
  });
  it('recombines a combined segment with the original parent', async () => {
    const rate4 = (await hedgey.plans('4')).rate;
    const amount4 = (await hedgey.plans('4')).amount;
    planEnd = await hedgey.planEnd('3');
    planRate = (await hedgey.plans('3')).rate;
    planAmount = (await hedgey.plans('3')).amount;
    expect(await hedgey.connect(b).combinePlans('3', '4')).to.emit('PlansCombined');
    expect(await hedgey.balanceOf(b.address)).to.eq(1);
    await expect(hedgey.ownerOf('4')).to.be.reverted;
    const postPlanEnd = await hedgey.planEnd('3');
    expect(postPlanEnd).to.eq(end);
    const plan3 = await hedgey.plans('3');
    expect(plan3.amount).to.eq(amount);
    expect(plan3.start).to.eq(start);
    expect(plan3.cliff).to.eq(cliff);
    expect(plan3.period).to.eq(period);
    const calcPlanRate = C.calcCombinedRate(planAmount, amount4, planRate, rate4, start, planEnd, period);
    expect(plan3.rate).to.eq(calcPlanRate);
  });
  it('segments the plan into 5 equal chunk sizes, and combines 2 and 5 together', async () => {
    segmentAmount = amount.div(5)
    await hedgey.createPlan(c.address, token.address, amount, start, cliff, rate, period);
    // created plan #6
    await hedgey.connect(c).segmentPlan('6', [segmentAmount, segmentAmount, segmentAmount, segmentAmount]);
    // numbers 6, 7, 8, 9, 10 exist owned by c
    expect(await hedgey.balanceOf(c.address)).to.eq(5);
    expect(await hedgey.ownerOf('6')).to.eq(c.address);
    expect(await hedgey.ownerOf('7')).to.eq(c.address);
    expect(await hedgey.ownerOf('8')).to.eq(c.address);
    expect(await hedgey.ownerOf('9')).to.eq(c.address);
    expect(await hedgey.ownerOf('10')).to.eq(c.address);
    const plan6 = await hedgey.plans('6');
    const plan7 = await hedgey.plans('7');
    const plan8 = await hedgey.plans('8');
    const plan9 = await hedgey.plans('9');
    const plan10 = await hedgey.plans('10');
    expect(plan6.amount).to.eq(segmentAmount);
    expect(plan7.amount).to.eq(segmentAmount);
    expect(plan8.amount).to.eq(segmentAmount);
    expect(plan9.amount).to.eq(segmentAmount);
    expect(plan10.amount).to.eq(segmentAmount);
    expect(plan6.amount.add(plan7.amount).add(plan8.amount).add(plan9.amount).add(plan10.amount)).to.eq(amount);
    expect((await hedgey.planEnd('6')).gte(end)).to.eq(true);
    expect((await hedgey.planEnd('7')).gte(end)).to.eq(true);
    expect((await hedgey.planEnd('8')).gte(end)).to.eq(true);
    expect((await hedgey.planEnd('9')).gte(end)).to.eq(true);
    expect((await hedgey.planEnd('10')).gte(end)).to.eq(true);
    //combine the plans
    await hedgey.connect(c).combinePlans('7', '10');
    expect((await hedgey.plans('7')).amount).to.eq(segmentAmount.mul(2));
    expect((await hedgey.planEnd('7')).gte(end)).to.eq(true);
  });
  it('redeems two segements from the same parent plan, and then combines them', async () => {
    await hedgey.connect(c).redeemPlans(['8', '9']);
    const plan8amount = (await hedgey.plans('8')).amount;
    const plan8rate = (await hedgey.plans('8')).rate;
    const plan9amount = (await hedgey.plans('9')).amount;
    const plan9rate = (await hedgey.plans('9')).rate;
    await hedgey.connect(c).combinePlans('8', '9');
    const postPlanEnd = await hedgey.planEnd('8');
    expect(postPlanEnd).to.eq(end);
    const plan8 = await hedgey.plans('8');
    expect(plan8.amount).to.eq(plan8amount.add(plan9amount));
    expect(plan8.start).to.eq(start);
    expect(plan8.cliff).to.eq(cliff);
    expect(plan8.period).to.eq(period);
    const calcCombinedRate = C.calcCombinedRate(plan8amount, plan9amount, plan8rate, plan9rate, start, end, period);
    expect(plan8.rate).to.eq(calcCombinedRate);
  });
};

const segmentVotingVaultTests = (params) => {
  let s, admin, a, b, c, d, hedgey, token;
  let amount, start, cliff, period, rate, end, planAmount, planRate, planEnd, segmentAmount, segmentRate, segmentEnd;
  let vaultAddress, segmentVault;
  it(`creates a plan, sets up voting, and then segments that plan`, async () => {
    s = await setup();
    hedgey = s.voteLocked;
    admin = s.admin;
    a = s.a;
    b = s.b;
    c = s.c;
    d = s.d;
    token = s.token;
    await token.approve(hedgey.address, C.E18_1000000);
    let now = await time.latest();
    
  });
  it('combines the two plans', async () => {
   
  });
  it('creates two same plans, only one sets up voting, then combines them', async () => {
    
  })
};

const segmentErrorTests = (voting) => {
  let s, admin, a, b, c, d, hedgey, token, dai;
  let amount, start, cliff, period, rate, segmentAmount;
  it('reverts if a user tries to segment a plan that does not exist', async () => {
    s = await setup();
    hedgey = voting ? s.voteLocked : s.locked;
    admin = s.admin;
    a = s.a;
    b = s.b;
    c = s.c;
    d = s.d;
    token = s.token;
    dai = s.dai;
    await token.approve(hedgey.address, C.E18_1000000.mul(10000));
    await dai.approve(hedgey.address, C.E18_1000000);
    let now = BigNumber.from(await time.latest());
    start = now;
    cliff = now;
    period = C.DAY;
    amount = C.E18_10000;
    segmentAmount = amount.div(2);
    rate = C.E18_1;
    await expect(hedgey.segmentPlan('1', [segmentAmount])).to.be.reverted;
  });
  it('reverst if a user tries to segment a plan they do not own', async () => {
    await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period);
    await expect(hedgey.segmentPlan('1', [segmentAmount])).to.be.revertedWith('!owner');
  });
  it('reverts if a user tries to segment a plan with the segment amount larger than the plan amount', async () => {
    await expect(hedgey.connect(a).segmentPlan('1', [amount])).to.be.revertedWith('amount error');
    await expect(hedgey.connect(a).segmentPlan('1', [amount.add(1)])).to.be.revertedWith('amount error');
  });
  it('reverts if a new segment is equal to 0', async () => {
    await expect(hedgey.connect(a).segmentPlan('1', [C.ZERO])).to.be.revertedWith('0_segment');
  });
  it('reverts if the segment amount is too small and creates a rate of 0', async () => {
    await expect(hedgey.connect(a).segmentPlan('1', [C.ONE])).to.be.revertedWith('0_rate');
    await expect(hedgey.connect(a).segmentPlan('1', ['100'])).to.be.revertedWith('0_rate');
  });
  it('reverts when combining plans with different tokens', async () => {
    await hedgey.createPlan(a.address, dai.address, amount, start, cliff, rate, period);
    await expect(hedgey.connect(a).combinePlans('1', '2')).to.be.revertedWith('token error');
  });
  it('reverts when combining two plans with different starts', async () => {
    await hedgey.createPlan(a.address, token.address, amount, start.add(C.DAY), cliff, rate, period);
    await expect(hedgey.connect(a).combinePlans('1', '3')).to.be.revertedWith('start error');
  });
  it('reverts when combining two plans with different cliffs', async () => {
    await hedgey.createPlan(a.address, token.address, amount, start, cliff.add(C.DAY), rate, period);
    await expect(hedgey.connect(a).combinePlans('1', '4')).to.be.revertedWith('cliff error');
  });
  it('reverts when combining two plans with different periods', async () => {
    await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, C.MONTH);
    await expect(hedgey.connect(a).combinePlans('1', '5')).to.be.revertedWith('period error');
  });
  it('reverts when combining two plans with different original or current end dates', async () => {
    await hedgey.createPlan(a.address, token.address, amount.add(C.E18_10), start, cliff, rate, period);
    await expect(hedgey.connect(a).combinePlans('1', '6')).to.be.revertedWith('end error');
  });
  it('reverts when a user tries to combine plans they do not own', async () => {
    await hedgey.createPlan(b.address, token.address, amount, start, cliff, rate, period);
    await expect(hedgey.connect(b).combinePlans('1', '7')).to.be.revertedWith('!owner');
    await expect(hedgey.connect(a).combinePlans('1', '7')).to.be.revertedWith('!owner');
  });
  it('reverts when a user combines plans that  would result in a shorter end date than the current or original end date', async () => {});
};

module.exports = {
  segmentTests,
  segmentVotingVaultTests,
  segmentErrorTests,
};
