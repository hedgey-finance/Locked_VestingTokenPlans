const C = require('./constants');
const adminTests = require('./tests/adminTests');
const happyPath = require('./tests/happyPath');
const { segmentTests, segmentVotingVaultTests, segmentErrorTests } = require('./tests/segmentTests');
const { claimTests, claimErrorTests } = require('./tests/claimTests');
const { createTests, createErrorTests } = require('./tests/createTests');
const { redeemTests, redeemSegmentCombineTests, redeemVotingVaultTests, redeemErrorTests } = require('./tests/redeemTests');
const { revokeTests, revokeErrorTests } = require('./tests/revokeTests');


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

// describe('Testing the create methods for minting a new plan', () => {
//   const paramsMatrix = [
//         {amount: C.E18_100, rate: C.E18_05, start: C.ZERO, period: C.DAY, cliff: C.DAY },
//         {amount: C.E18_1000.mul(7), rate: C.E18_10.mul(13), start: C.ZERO, period: C.DAY, cliff: C.DAY },
//       ];
//       paramsMatrix.forEach((params) => {
//         createTests(true, true, params);
//         createTests(true, false, params);
//         createTests(false, true, params);
//         createTests(false, false, params);
//       });
//       createErrorTests(true, true);
//       createErrorTests(true, false);
//       createErrorTests(false, true);
//       createErrorTests(false, false);
// })

// describe('Testing redeeming funtions', () => {
//   const paramsMatrix = [
//     { amount: C.E18_1000, rate: C.E18_05, start: C.ZERO, period: C.ONE, cliff: C.ONE.mul(50) },
//     { amount: C.E18_1000.mul(7), rate: C.E18_10.mul(13), start: C.ZERO, period: C.DAY, cliff: C.DAY },
//   ];
//   paramsMatrix.forEach((params) => {
//     redeemTests(true, true, params);
//     redeemTests(true, false, params);
//     redeemTests(false, true, params);
//     redeemTests(false, false, params);
//     redeemSegmentCombineTests(true, params);
//     redeemSegmentCombineTests(false, params);
//     redeemVotingVaultTests(true, params);
//     redeemVotingVaultTests(false, params);
//   });
//   redeemErrorTests(true, true);
// });

describe('Testing the revoke functions', () => {
  const paramsMatrix = [
        { amount: C.E18_1000, rate: C.E18_05, start: C.ZERO, period: C.ONE, cliff: C.ONE.mul(50) },
        { amount: C.E18_1000.mul(7), rate: C.E18_10.mul(13), start: C.ZERO, period: C.DAY, cliff: C.DAY },
      ];
      paramsMatrix.forEach((params) => {
        revokeTests(true, params);
        revokeTests(false, params);
      });
  revokeErrorTests(true);
  revokeErrorTests(false);
});


// describe('Testing the Segmentation and Combination Methods', () => {
//   const paramsMatrix = [
//     {
//       amount: C.E18_1000,
//       period: C.DAY,
//       rate: C.E18_10,
//       start: 0,
//       cliff: C.DAY,
//       segmentAmount: C.E18_100.mul(5),
//       secondSegment: C.E18_100,
//     },
//     {
//       amount: C.E18_1000.mul(8),
//       period: C.DAY,
//       rate: C.E18_10,
//       start: 0,
//       cliff: C.WEEK,
//       segmentAmount: C.E18_100,
//       secondSegment: C.E18_100.mul(3),
//     },
//     {
//       amount: C.E18_1000.mul(12),
//       period: C.DAY,
//       rate: C.E18_12,
//       start: 0,
//       cliff: C.WEEK,
//       segmentAmount: C.E18_1000,
//       secondSegment: C.E18_1000.mul(3),
//     },
//     { amount: C.E18_10000, period: C.DAY, rate: C.E18_12, start: 0, cliff: C.WEEK, segmentAmount: C.E18_1000.mul(7), secondSegment: C.E18_100.mul(5) },
//     {
//       amount: C.E18_10000.mul(7),
//       period: C.WEEK,
//       rate: C.E18_13.mul(10),
//       start: 0,
//       cliff: C.MONTH,
//       segmentAmount: C.E18_13.mul(100),
//       secondSegment: C.E18_100.mul(2)
//     },
//     {
//       amount: C.E18_10000.mul(72),
//       period: C.WEEK,
//       rate: C.E18_13.mul(10),
//       start: C.DAY,
//       cliff: C.MONTH,
//       segmentAmount: C.E18_1000.mul(43),
//       secondSegment: C.E18_100.mul(4)
//     },
//   ];
//   paramsMatrix.forEach((params) => {
//     segmentTests(false, params);
//     segmentTests(true, params);
//     segmentVotingVaultTests(params);
//   });
// });

// describe('Testing the Claim Campaign tests', () => {
//   const paramsMatrix = [
//     {totalRecipients: 100, nodeA: 5, nodeB: 33, rate: C.E18_05, start: C.ZERO, period: C.DAY, cliff: C.DAY },
//     {totalRecipients: 10, nodeA: 5, nodeB: 12, rate: C.E18_05, start: C.ZERO, period: C.DAY, cliff: C.DAY },
//   ]
//   paramsMatrix.forEach((params) => {
//     claimTests(0, false, params);
//     claimTests(1, true, params);
//     claimTests(1, false, params);
//     claimTests(2, true, params);
//     claimTests(2, false, params);
//   });
//   claimErrorTests();

// });
