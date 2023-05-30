const C = require('./constants');
const happyPath = require('./tests/happyPath');

const paramsMatrix = [
  { amount: C.E18_100, interval: C.DAY, rate: C.E18_10, start: 0, cliff: 0, unlock: 0 },
];

describe('Testing the Happy Path', () => {
  paramsMatrix.forEach((params) => {
    //happyPath(true, params);
    happyPath(false, params);
  });
});
