const { expect } = require('chai');
const { setup } = require('../fixtures');
const { time } = require('@nomicfoundation/hardhat-network-helpers');
const C = require('../constants');
const { BigNumber } = require('ethers');

module.exports = (voting, params) => {
  let s, admin, a, b, c, d, hedgey, token;
  let amount, start, cliff, period, rate, end, planAmount, planRate, planEnd, segmentAmount, segmentRate, segmentEnd;
  it('mints a plan and creates a segment', async () => {
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
    planRate = rate.mul((dPlanAmt).div(amount));
    planRate = planRate.div(C.E18_1);
    console.log(`test plan rate: ${planRate}`);
    segmentRate = rate.sub(planRate);
    console.log(`test segment rate: ${segmentRate}`);
    start = BigNumber.from(now).add(params.start);
    cliff = BigNumber.from(now).add(params.cliff);
    end = C.planEnd(start, amount, rate, period);
    await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period);
    // now holder A will segment it into two plans
    await hedgey.connect(a).segmentPlan('1', segmentAmount);
    // check the two plans
    const calcPlanEnd = C.planEnd(start, planAmount, planRate, period);
    const calcSegEnd = C.planEnd(start, segmentAmount, segmentRate, period);
    planEnd = await hedgey.planEnd('1');
    segmentEnd = await hedgey.planEnd('2');
    console.log(`calced Plan End: ${calcPlanEnd}`);
    console.log(`calced segment end: ${calcSegEnd}`);
    console.log(`new plan end: ${planEnd}`);
    console.log(`segment end: ${segmentEnd}`);
    expect(calcPlanEnd).to.eq(planEnd);
    expect(calcSegEnd).to.eq(segmentEnd);
    expect(planEnd).to.eq(segmentEnd);
  });
};
