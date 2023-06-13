const { expect } = require('chai');
const { setup } = require('../fixtures');
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
    // console.log(`test plan rate: ${planRate}`);
    segmentRate = rate.sub(planRate);
    // console.log(`test segment rate: ${segmentRate}`);
    start = BigNumber.from(now).add(params.start);
    cliff = BigNumber.from(now).add(params.cliff);
    end = C.planEnd(start, amount, rate, period);
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
    // expect(planEnd).to.be.greaterThanOrEqual(end);
    // expect(segmentEnd).to.be.greaterThanOrEqual(end);
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
  });
  it('Recombines the two segmented plans', async () => {
    // going to recombine plans 1 and two
    expect(await hedgey.connect(a).combinePlans('1', '2'))
      .to.emit('PlansCombined')
      .withArgs('1', '2', '1', amount, rate, start, cliff, period, end);
    // check that the 
  });
  it('segments plan 1 with two segments', async () => {
    const secondSegment = params.secondSegment
    await hedgey.connect(a).segmentPlan('1', [segmentAmount, secondSegment]);
    
  });
  it('recombines segment 3 and 4 together, and then combines the original plan 1 with the survivor', async () => {
    const tx = await hedgey.connect(a).combinePlans('3', '4');
    const data = (await tx.wait()).events[2].args;
    const survivor = data.survivingId;
    await hedgey.connect(a).combinePlans('1', survivor);
  });
};

const segmentVotingTests = (params) => {
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
  })
}

const segmentErrorTests = () => {

}

module.exports = {
    segmentTests,
    segmentVotingTests,
    segmentErrorTests,
};
