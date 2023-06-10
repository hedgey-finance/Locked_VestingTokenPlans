const C = require('./constants');
const adminTests = require('./tests/adminTests');
const happyPath = require('./tests/happyPath');
const segmentTests = require('./tests/segmentTests')


// describe('Testing the URI Admin functions', () => {
//   adminTests(true, false);
//   adminTests(true, true);
//   adminTests(false, false);
//   adminTests(false, true);
// })

// describe('Testing the Happy Path', () => {
//   const paramsMatrix = [
//     { amount: C.E18_1000, period: C.DAY, rate: C.E18_10, start: 0, cliff: C.DAY, balanceCheck: C.WEEK },
//     { amount: C.E18_1000, period: C.DAY, rate: C.E18_10, start: 0, cliff: C.WEEK, balanceCheck: C.WEEK },
//     { amount: C.E18_10000.mul(7), period: C.WEEK, rate: C.E18_13.mul(10), start: 0, cliff: C.MONTH, balanceCheck: C.DAY.mul(34) }
//   ];
//   paramsMatrix.forEach((params) => {
//     happyPath(true, true, params);
//     happyPath(true, false, params);
//     happyPath(false, true, params);
//     happyPath(false, false, params);
//   });
// });


describe('Testing the Segmentation and Combination Methods', () => {
  const paramsMatrix = [
    { amount: C.E18_1000, period: C.DAY, rate: C.E18_10, start: 0, cliff: C.DAY, segmentAmount: C.E18_100.mul(5) },
    { amount: C.E18_1000.mul(8), period: C.DAY, rate: C.E18_10, start: 0, cliff: C.WEEK, segmentAmount: C.E18_100 },
    { amount: C.E18_10000.mul(7), period: C.WEEK, rate: C.E18_13.mul(10), start: 0, cliff: C.MONTH, segmentAmount: C.E18_13.mul(100) }
  ];
  paramsMatrix.forEach((params) => {
    segmentTests(false, params);
  });
});
