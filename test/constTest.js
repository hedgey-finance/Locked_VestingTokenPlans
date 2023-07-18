// const { BigNumber } = require('ethers');
// const C = require('./constants');

// let plan = {
//   amount: C.E18_100.add(700777),
//   period: C.ONE,
//   rate: C.E18_10.div(60).div(60).div(24).div(365).div(2),
//   start: 0,
// };

// // let plan = {
// //   amount: C.E18_10000,
// //   period: C.MONTH,
// //   rate: C.E18_10000.div(10).div(1),
// //   start: 0,
// // };

// const planEnd = C.planEnd(plan.start, plan.amount, plan.rate, plan.period);
// //console.log(`original plan end: ${planEnd}`);

// const calcCombinedRate = (amountA, amountB, rateA, rateB, start, end, period) => {
//   const amount = amountA.add(amountB);
//   const numerator = amount.mul(period);
//   const combinedRate = rateA.add(rateB);
//   console.log(`added combined rate: ${combinedRate}`);
//   let denominator = BigNumber.from(end).sub(start);
//   if (amount.mod(combinedRate) == 0) {
//     console.log('should use the add method');
//   } else {
//     denominator = denominator.sub(period);
//     console.log('checking the alt method');
//   }
//   return numerator.div(denominator);
// };

// function segmentPlan(segmentAmount) {
//   const _planAmount = plan.amount.sub(segmentAmount);
//   const _planRate = C.proratePlanRate(plan.amount, _planAmount, plan.rate);
//   const _planEnd = C.planEnd(plan.start, _planAmount, _planRate, plan.period);
//   const segmentRate = C.calcPlanRate(segmentAmount, plan.period, planEnd, plan.start, plan.rate, _planRate);
//   const segmentEnd = C.planEnd(plan.start, segmentAmount, segmentRate, plan.period);
//   const combinedPlanRate = segmentRate.add(_planRate);
//   console.log(`new plan end: ${_planEnd}`);
//   console.log(`segment end: ${segmentEnd}`);
//   console.log(`difference in end dates: ${segmentEnd.sub(_planEnd).div(plan.period)}`);
//   console.log(`new plan rate: ${_planRate}`);
//   console.log(`segment rate: ${segmentRate}`);
//   console.log(`ratio of segmented rates: ${_planRate.div(segmentRate)}`);
//   console.log(`ratio of amounts: ${_planAmount.div(segmentAmount)}`);
//   const combinedRateCheck = calcCombinedRate(
//     _planAmount,
//     segmentAmount,
//     _planRate,
//     segmentRate,
//     plan.start,
//     planEnd,
//     plan.period
//   );
//   console.log(`checking recombined plan rate: ${combinedRateCheck}`);
//   console.log(`combined rate: ${combinedPlanRate}`);
//   console.log(`difference of combined add vs new combined: ${combinedRateCheck.sub(combinedPlanRate)}`);
//   console.log(`original rate: ${plan.rate}`);
//   console.log(`compare rates: ${plan.rate.sub(combinedPlanRate)}`);
//   console.log(`compare rates with new calc: ${plan.rate.sub(combinedRateCheck)}`);
//   const combinedEnd = C.planEnd(plan.start, _planAmount.add(segmentAmount), combinedPlanRate, plan.period);
//   console.log(`a combined end would be: ${combinedEnd}`);

//   // check the total number of tokens earned 1 period before the end
//   const originalBalanceCheck = C.balanceAtTime(
//     plan.start,
//     plan.start,
//     plan.amount,
//     plan.rate,
//     plan.period,
//     planEnd.sub(plan.period),
//     planEnd.sub(plan.period)
//   );
//   const planBalanceCheck = C.balanceAtTime(
//     plan.start,
//     plan.start,
//     _planAmount,
//     _planRate,
//     plan.period,
//     _planEnd.sub(plan.period),
//     _planEnd.sub(plan.period)
//   );
//   const segmentBalanceCheck = C.balanceAtTime(
//     plan.start,
//     plan.start,
//     segmentAmount,
//     segmentRate,
//     plan.period,
//     _planEnd.sub(plan.period),
//     _planEnd.sub(plan.period)
//   );
//   const bal = originalBalanceCheck.balance;
//   console.log(`original balance check: ${bal.div(C.E6_1)}`);
//   const planBal = planBalanceCheck.balance;
//   const segmentBal = segmentBalanceCheck.balance;
//   const combinedBal = planBal.add(segmentBal);
//   console.log(`combined check: ${combinedBal.div(C.E6_1)}`);
//   console.log(`final check: ${bal.sub(combinedBal)}`);
// }

//segmentPlan(C.E18_1.mul(10));
