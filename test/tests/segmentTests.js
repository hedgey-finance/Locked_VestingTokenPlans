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
  let amount, start, cliff, period, rate, end, planAmount, planRate, planEnd, segmentAmount, segmentRate, segmentEnd;
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
    segmentAmount = params.segmentAmount;
    planAmount = amount.sub(segmentAmount);
    period = params.period;
    rate = params.rate;
    let dPlanAmt = planAmount.mul(C.E18_1);
    planRate = rate.mul(dPlanAmt.div(amount));
    planRate = planRate.div(C.E18_1);
    segmentRate = rate.sub(planRate);
    start = BigNumber.from(now).add(params.start);
    cliff = start.add(params.cliff);
    end = C.planEnd(start, amount, rate, period);
    console.log(`original plan end: ${end}`)
    await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period);
    // now holder A will segment it into two plans
    expect(await hedgey.connect(a).segmentPlan('1', [segmentAmount]))
      .to.emit('PlanSegmented')
      .withArgs('1', '2', planAmount, planRate, segmentAmount, segmentRate, start, cliff, period, segmentEnd);
    // check the two plans
    const calcPlanEnd = C.planEnd(start, planAmount, planRate, period);
    const calcSegEnd = C.planEnd(start, segmentAmount, segmentRate, period);
    planEnd = await hedgey.planEnd('1');
    segmentEnd = await hedgey.planEnd('2');
    expect(calcPlanEnd).to.eq(planEnd);
    expect(calcSegEnd).to.eq(segmentEnd);
    const plan = await hedgey.plans('1');
    const segment = await hedgey.plans('2');
    expect(plan.token).to.eq(segment.token);
    expect(plan.amount).to.eq(planAmount);
    expect(segment.amount).to.eq(segmentAmount);
    expect(plan.amount.add(segment.amount)).to.eq(amount);
    expect(plan.start).to.eq(start);
    expect(segment.start).to.eq(start);
    expect(plan.cliff).to.eq(cliff);
    expect(segment.cliff).to.eq(cliff);
    expect(plan.period).to.eq(period);
    expect(segment.period).to.eq(period);
    expect(plan.rate.add(segment.rate)).to.eq(rate);
    expect(await hedgey.balanceOf(a.address)).to.eq(2);
    expect(await hedgey.ownerOf('1')).to.eq(a.address);
    expect(await hedgey.ownerOf('2')).to.eq(a.address);
    console.log(`plan 1 end: ${planEnd}`);
    console.log(`segment end: ${segmentEnd}`);
  });
  it('Recombines the two segmented plans', async () => {
    // going to recombine plans 1 and two
    expect(await hedgey.connect(a).combinePlans('1', '2'))
      .to.emit('PlansCombined')
      .withArgs('1', '2', '1', amount, rate, start, cliff, period, end);
    // check that the 
    const plan = await hedgey.plans('1');
    expect(plan.token).to.eq(token.address);
    expect(plan.amount).to.eq(amount);
    expect(plan.start).to.eq(start);
    expect(plan.rate).to.eq(rate);
    expect(plan.cliff).to.eq(cliff);
    expect(plan.period).to.eq(period);
    const _end = await hedgey.planEnd('1');
    expect(_end).to.eq(end);
    console.log(`recombined end: ${_end}`);
  });
  it('segments plan 1 with two segments', async () => {
    const secondSegment = params.secondSegment
    await hedgey.connect(a).segmentPlan('1', [segmentAmount, secondSegment]);
    
  });
  it('recombines two children segments together', async () => {
    const plan3 = await hedgey.plans('3');
    const plan4 = await hedgey.plans('4');
    const combinedAmount = plan3.amount.add(plan4.amount);
    const combinedRate = plan3.rate.add(plan4.rate);
    let expectedEnd = C.planEnd(start, combinedAmount, combinedRate, period);
    expect(await hedgey.connect(a).combinePlans('3', '4')).to.emit('PlansCombined').withArgs('3', '4', '3', combinedAmount, combinedRate, start, cliff, period, expectedEnd);
    const combinedPlan = await hedgey.plans('3');
    expect(combinedPlan.amount).to.eq(combinedAmount);
    expect(combinedPlan.rate).to.eq(combinedRate);
    expect(combinedPlan.start).to.eq(start);
    expect(combinedPlan.cliff).to.eq(cliff);
    expect(combinedPlan.period).to.eq(period);
    expect(await hedgey.planEnd('3')).to.eq(expectedEnd);
    expect(await hedgey.balanceOf(a.address)).to.eq(2);
    expect(await token.balanceOf(hedgey.address)).to.eq(amount);
  });
  it('recombines a combined segment with the original parent', async () => {
    await hedgey.connect(a).combinePlans('1', '3');
    expect(await hedgey.balanceOf(a.address)).to.eq(1);
    expect(await token.balanceOf(hedgey.address)).to.eq(amount);
    const plan = await hedgey.plans('1');
    expect(plan.amount).to.eq(amount);
    expect(plan.rate).to.eq(rate);
    expect(plan.start).to.eq(start);
    expect(plan.cliff).to.eq(cliff);
    expect(plan.period).to.eq(period);
    expect(await hedgey.planEnd('1')).to.eq(end);
    // everything is now recombined again
  });
  it('segments the plan into 5 equal chunk sizes, and combines 2 and 5 together', async () => {
    let segmentSize = amount.div(5);
    let segmentRate = rate.div(5);
    // segments should be 4 to create a total of 5
    await hedgey.connect(a).segmentPlan('1', [segmentSize, segmentSize, segmentSize, segmentSize]);
    const plan2 = await hedgey.plans('5');
    const plan5 = await hedgey.plans('8');
    expect(plan2.amount).to.eq(segmentSize);
    expect(plan5.amount).to.eq(segmentSize);
    // console.log(await hedgey.planEnd('5'));
    // console.log(await hedgey.planEnd('8'));
    expect(await hedgey.segmentOriginalEnd('5')).to.eq(end);
    expect(await hedgey.segmentOriginalEnd('8')).to.eq(end);
    expect(await hedgey.segmentOriginalEnd('1')).to.eq(end);
    expect(await hedgey.connect(a).combinePlans('5', '8')).to.emit('PlansCombined').withArgs('5', '8', '5', segmentSize.add(segmentSize), segmentRate, start, cliff, period, end);
    expect((await hedgey.planEnd('5')).gte(end)).to.be.true;
    // console.log(`new plan5 end: ${await hedgey.planEnd('5')}`);
    // console.log(`end: ${end}`);
  });
  it('redeems two segements from the sam parent plan, and then combines them', async () => {
    //redeeming plan 1 and plan 6
    await time.increaseTo(cliff.add(period));
    await hedgey.connect(a).redeemPlans(['1', '6']);
    await hedgey.connect(a).combinePlans('1', '6');
  });
  it('partially redeems two segments from the same parent plan, and then combines them', async () => {
    let now = await time.latest();
    await time.increase(period.mul(2));
    await hedgey.connect(a).partialRedeemPlans(['1', '7'], period.add(now));
    await hedgey.connect(a).combinePlans('1', '7');
  });
  it('creates two new plans with the same data, and the combines them', async () => {
    // create plans 9 and 10
    await hedgey.createPlan(a.address, token.address, segmentAmount, start, start, rate, period);
    await hedgey.createPlan(a.address, token.address, segmentAmount, start, start, rate, period);
    await hedgey.connect(a).combinePlans('9', '10');
  });
  it('creates two new plans with same data, segments them, and then combines the two unrelated segments', async () => {
    // create plans 11 and 12
    await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period);
    await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period);
    await hedgey.connect(a).segmentPlan('11', [segmentAmount]);
    await hedgey.connect(a).segmentPlan('12', [segmentAmount]);
    await hedgey.connect(a).combinePlans('11', '12');
    await hedgey.connect(a).combinePlans('13', '14');
  });
  it('creates two new plans with similar data, but different amounts and rates, but same end dates and combines them', async () => {
    // plans 15 and 16
    let amtA = C.E18_1000.mul(3);
    let amtB = C.E18_1000.mul(6);
    let rateA = C.E18_10;
    let rateB = C.E18_10.mul(2);
    await hedgey.createPlan(a.address, token.address, amtA, start, start, rateA, period);
    await hedgey.createPlan(a.address, token.address, amtB, start, start, rateB, period);
    await hedgey.connect(a).combinePlans('15', '16');
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
    amount = params.amount;
    segmentAmount = params.segmentAmount;
    planAmount = amount.sub(segmentAmount);
    period = params.period;
    rate = params.rate;
    let dPlanAmt = planAmount.mul(C.E18_1);
    planRate = rate.mul(dPlanAmt.div(amount));
    planRate = planRate.div(C.E18_1);
    segmentRate = rate.sub(planRate);
    start = BigNumber.from(now).add(params.start);
    cliff = BigNumber.from(now).add(params.cliff);
    end = C.planEnd(start, amount, rate, period);
    await hedgey.createPlan(a.address, token.address , amount, start, cliff, rate, period);
    const tx = await hedgey.connect(a).setupVoting(1);
    vaultAddress = (await tx.wait()).events[3].args.vaultAddress;
    expect(await token.balanceOf(vaultAddress)).to.eq(amount);
    const segTx = await hedgey.connect(a).segmentPlan('1', [segmentAmount]);
    segmentVault = (await segTx.wait()).events[6].args.vaultAddress;
    expect(await token.balanceOf(vaultAddress)).to.eq(planAmount);
    expect(await token.balanceOf(segmentVault)).to.eq(segmentAmount);
    expect(await token.delegates(vaultAddress)).to.eq(a.address);
    expect(await token.delegates(segmentVault)).to.eq(a.address);
    await hedgey.connect(a).delegate(2, b.address);
    expect(await token.delegates(segmentVault)).to.eq(b.address);
    expect(await token.delegates(vaultAddress)).to.eq(a.address);
  });
  it('combines the two plans', async () => {
    await hedgey.connect(a).combinePlans(1, 2);
    expect(await token.balanceOf(vaultAddress)).to.eq(amount);
    expect(await token.balanceOf(segmentVault)).to.eq(0);
    expect(await token.delegates(vaultAddress)).to.eq(a.address);
  });
}

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
    amount = C.E18_10000
    segmentAmount = amount.div(2);
    rate = C.E18_1;
    await (expect(hedgey.segmentPlan('1', [segmentAmount]))).to.be.reverted;
    
  });
  it('reverst if a user tries to segment a plan they do not own', async () => {
    await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period);
    await (expect(hedgey.segmentPlan('1', [segmentAmount]))).to.be.revertedWith('!owner');
  });
  it('reverts if a user tries to segment a plan with the segment amount larger than the plan amount', async () => {
    await (expect(hedgey.connect(a).segmentPlan('1', [amount]))).to.be.revertedWith('amount error');
    await (expect(hedgey.connect(a).segmentPlan('1', [amount.add(1)]))).to.be.revertedWith('amount error');
  });
  it('reverts if a new segment is equal to 0', async () => {
    await (expect(hedgey.connect(a).segmentPlan('1', [C.ZERO]))).to.be.revertedWith('0_segment');
  });
  it('reverts if the segment amount is too small and creates a rate of 0', async () => {
    await (expect(hedgey.connect(a).segmentPlan('1', [C.ONE]))).to.be.revertedWith('segmentEnd error');
    await (expect(hedgey.connect(a).segmentPlan('1', ['100']))).to.be.revertedWith('segmentEnd error');
    
  });
  it('reverts when combining plans with different tokens', async () => {
    await hedgey.createPlan(a.address, dai.address, amount, start, cliff, rate, period);
    await expect(hedgey.connect(a).combinePlans('1', '2')).to.be.revertedWith('token error');
  })
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
  it('reverts when a user combines plans that  would result in a shorter end date than the current or original end date', async () => {

  });
}

module.exports = {
    segmentTests,
    segmentVotingVaultTests,
    segmentErrorTests,
};
