const { BigNumber } = require('ethers');
const C = require('./constants');
require("dotenv").config({path: "../.env"});

let planA = {
  amount: C.E18_1000000,
  period: C.ONE,
  rate: C.E18_1000000.div(60).div(60).div(24).div(365).div(3),
  start: 0,
};

// let plan = {
//   amount: C.E18_10000,
//   period: C.MONTH,
//   rate: C.E18_10000.div(10).div(1),
//   start: 0,
// };


const paramsMatrix = [
  {
    amount: C.E18_1000,
    period: C.DAY,
    rate: C.E18_10,
    start: C.ZERO,
    cliff: C.DAY,
    segmentAmount: C.E18_100.mul(5),
    secondSegment: C.E18_100,
    test: 1,
  },
  {
    amount: C.E18_1000.mul(8),
    period: C.DAY,
    rate: C.E18_10,
    start: C.ZERO,
    cliff: C.WEEK,
    segmentAmount: C.E18_100,
    secondSegment: C.E18_100.mul(3),
    test: 2,
  },
  {
    amount: C.E18_1000.mul(12),
    period: C.DAY,
    rate: C.E18_12,
    start: C.ZERO,
    cliff: C.WEEK,
    segmentAmount: C.E18_1000,
    secondSegment: C.E18_1000.mul(3),
    test: 3,
  },
  {
    amount: C.E18_10000,
    period: C.DAY,
    rate: C.E18_12,
    start: C.ZERO,
    cliff: C.WEEK,
    segmentAmount: C.E18_1000.mul(7),
    secondSegment: C.E18_100.mul(5),
    test: 4,
  },
  {
    amount: C.E18_10000.mul(7),
    period: C.WEEK,
    rate: C.E18_13.mul(10),
    start: C.ZERO,
    cliff: C.MONTH,
    segmentAmount: C.E18_13.mul(100),
    secondSegment: C.E18_100.mul(2),
    test: 5,
  },
  {
    amount: C.E18_10000.mul(72),
    period: C.WEEK,
    rate: C.E18_13.mul(10),
    start: C.ZERO,
    cliff: C.MONTH,
    segmentAmount: C.E18_1000.mul(43),
    secondSegment: C.E18_100.mul(4),
    test: 6,
  },
  {
    amount: C.E18_10000.mul(80),
    period: C.ONE,
    rate: C.E12_1.mul(10000),
    start: C.ZERO,
    cliff: C.DAY,
    segmentAmount: C.E18_1000,
    secondSegment: C.E18_1000.mul(5),
    test: 7,
  },
  {
    amount: C.E18_10000.mul(45),
    period: C.ONE,
    rate: C.E12_1.mul(10000),
    start: C.ZERO,
    cliff: C.DAY,
    segmentAmount: C.E18_05.mul(9),
    secondSegment: C.E18_1000.mul(5),
    test: 8,
  },
  {
    amount: C.E18_1000000,
    period: C.ONE,
    rate: C.E18_1000000.div(60).div(60).div(24).div(365).div(2),
    start: C.WEEK,
    cliff: C.WEEK,
    segmentAmount: C.E18_1000000.div(2),
    secondSegment: C.E18_1000.mul(5),
    test: 9,
  },
  {
    amount: C.E18_1000000,
    period: C.ONE,
    rate: C.E18_1000000.div(60).div(60).div(24).div(365),
    start: -86500,
    cliff: C.WEEK,
    segmentAmount: C.E18_1000000.sub(C.E18_7500),
    secondSegment: C.E18_7500.div(2),
    test: 10,
  },
  {
    amount: C.E18_1000000,
    period: C.MONTH,
    rate: C.E18_1000000.div(12).div(3),
    start: C.ZERO,
    cliff: C.MONTH.mul(2),
    segmentAmount: C.E18_1000000.sub(C.E18_10000),
    secondSegment: C.E18_10000.div(7),
    test: 11,
  },
];
const calcCombinedRate = (amountA, amountB, rateA, rateB, start, end, period) => {
  const amount = amountA.add(amountB);
  const numerator = amount.mul(period);
  const combinedRate = rateA.add(rateB);
  let denominator = BigNumber.from(end).sub(start);
  if (amount.mod(combinedRate) == 0) {
    
  } else {
    denominator = denominator.sub(period);
    
  }
  return numerator.div(denominator);
};

function segmentPlan(plan, segmentAmount) {
  let newCalc = 0;
  let oldCalc = 0;
  const planEnd = C.planEnd(plan.start, plan.amount, plan.rate, plan.period);
  const _planAmount = plan.amount.sub(segmentAmount);
  let _planRate = C.proratePlanRate(plan.amount, _planAmount, plan.rate);
  let _calcPlanRate = C.calcPlanRate(_planAmount, plan.period, planEnd, plan.start, plan.rate, _planRate);
  const _planEnd = C.planEnd(plan.start, _planAmount, _calcPlanRate, plan.period);
  const _calcPlanEnd = C.planEnd(plan.start, _planAmount, _planRate, plan.period);
  const segmentRate = C.calcPlanRate(segmentAmount, plan.period, planEnd, plan.start, plan.rate, _planRate);
  const segmentRateNew = C.calcPlanRate(segmentAmount, plan.period, planEnd, plan.start, plan.rate, _calcPlanRate);
  const segmentEnd = C.planEnd(plan.start, segmentAmount, segmentRate, plan.period);
  // console.log(`_planRate: ${_planRate}`);
  // console.log(`_calPlanRate: ${_calcPlanRate}`);
  // console.log(`segment rate: ${segmentRate}`);
  // console.log(`_planEnd: ${_planEnd}`);
  // console.log(`_calcPlanEnd: ${_calcPlanEnd}`);
  // console.log(`segment end: ${segmentEnd}`);
  if (_planEnd > planEnd) {
    oldCalc++;
    // console.log('plan ends arent the same');
    // console.log(`_planEnd: ${_planEnd}`);
  }
  if (_calcPlanEnd > planEnd) {
    newCalc++;
    // console.log('new calculated plan ends arent the same');
    // console.log(`_calcPlanEnd: ${_calcPlanEnd}`);
    
  }
  if (segmentEnd > planEnd) {
    oldCalc++;
    // console.log('segment end isnt the same');
    // console.log(`segment end: ${segmentEnd}`);
  }
  if (segmentRateNew > planEnd) {
    newCalc++;
  }
  //console.log(`original end: ${planEnd}`);
  const combinedPlanRate = calcCombinedRate(
    _planAmount,
    segmentAmount,
    _calcPlanRate,
    segmentRate,
    plan.start,
    planEnd,
    plan.period
  )
  const combinedRateCheck = calcCombinedRate(
    _planAmount,
    segmentAmount,
    _planRate,
    segmentRate,
    plan.start,
    planEnd,
    plan.period
  );
  if (combinedPlanRate > plan.rate) {
    newCalc++;
    // console.log('new combined rate calc not the same');
    // console.log(`combined rate: ${combinedPlanRate}`);
  }
  if (combinedRateCheck > plan.rate) {
    oldCalc++;
    // console.log('current plan rate calc isnt the same');
    // console.log(`rate combined is: ${combinedRateCheck}`);
  }
  // console.log(`original plan rate: ${plan.rate}`);
  // console.log(`combined rate: ${combinedPlanRate}`);
  // console.log(`combined pro rata rate: ${combinedRateCheck}`);
  // console.log(`original rate: ${plan.rate}`);
  // console.log(`compare rates: ${plan.rate.sub(combinedPlanRate)}`);
  // console.log(`compare rates with new calc: ${plan.rate.sub(combinedRateCheck)}`);
  //const combinedEnd = C.planEnd(plan.start, _planAmount.add(segmentAmount), combinedPlanRate, plan.period);
  // console.log(`a combined end would be: ${combinedEnd}`);

  // // check the total number of tokens earned 1 period before the end
  // const originalBalanceCheck = C.balanceAtTime(
  //   plan.start,
  //   plan.start,
  //   plan.amount,
  //   plan.rate,
  //   plan.period,
  //   planEnd.sub(plan.period),
  //   planEnd.sub(plan.period)
  // );
  // const planBalanceCheck = C.balanceAtTime(
  //   plan.start,
  //   plan.start,
  //   _planAmount,
  //   _planRate,
  //   plan.period,
  //   _planEnd.sub(plan.period),
  //   _planEnd.sub(plan.period)
  // );
  // const segmentBalanceCheck = C.balanceAtTime(
  //   plan.start,
  //   plan.start,
  //   segmentAmount,
  //   segmentRate,
  //   plan.period,
  //   _planEnd.sub(plan.period),
  //   _planEnd.sub(plan.period)
  // );
  // const bal = originalBalanceCheck.balance;
  // console.log(`original balance check: ${bal.div(C.E6_1)}`);
  // const planBal = planBalanceCheck.balance;
  // const segmentBal = segmentBalanceCheck.balance;
  // const combinedBal = planBal.add(segmentBal);
  // console.log(`combined check: ${combinedBal.div(C.E6_1)}`);
  // console.log(`final check: ${bal.sub(combinedBal)}`);
  return {
    oldCalc,
    newCalc,
  }
}

paramsMatrix.forEach(plan => {
  let old = 0;
  let n = 0;
  let num = segmentPlan(plan, plan.segmentAmount);
  old += num.oldCalc;
  n += num.newCalc;
  console.log(`old: ${old}`);
  console.log(`new: ${n}`)
})
