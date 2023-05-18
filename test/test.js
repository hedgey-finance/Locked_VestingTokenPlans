const C = require('./constants');
const happyPath = require('./tests/happyPath');

const paramsMatrix = [
  //{ amounts: [C.E18_100, C.E18_200, C.E18_500], timeShifts: [100, 50, 1], unlockShift: 0 },
  {
    amounts: [
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
      C.E18_100,
    ],
    timeShifts: [
      36, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8,
      7, 6, 5, 4, 3, 2, 1,
    ],
    unlockShift: 0,
  },
];

describe('Testing the Happy Path', () => {
  paramsMatrix.forEach((params) => {
    happyPath(true, params);
    happyPath(false, params);
  });
});
