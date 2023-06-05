const C = require('./constants');
const happyPath = require('./tests/happyPath');

const paramsMatrix = [
  { amount: C.E18_1000, period: C.DAY, rate: C.E18_10, start: 0, cliff: 0, unlock: 0 },
];

describe('Testing the Happy Path', () => {
  paramsMatrix.forEach((params) => {
    //happyPath(true, true, params);
    happyPath(true, false, params);
    //happyPath(false, true, params);
    happyPath(false, false, params);
  });
});
