const BigNumber = require('ethers').BigNumber;
const { ethers } = require('hardhat');

const bigMin = (a, b) => {
  if (a.lte(b)) return a;
  else return b;
};

const randomBigNum = (base, max, min) => {
  let num = Math.round(Math.random() * max);
  num = Math.max(num, min);
  return BigNumber.from(10).pow(base).mul(num);
};

const getVal = (amount) => {
  return ethers.utils.formatEther(amount);
}

module.exports = {
  ZERO: BigNumber.from(0),
  ONE: BigNumber.from(1),
  E6_1: BigNumber.from(10).pow(6),
  E6_2: BigNumber.from(10).pow(6).mul(2),
  E6_5: BigNumber.from(10).pow(6).mul(5),
  E6_10: BigNumber.from(10).pow(6).mul(10),
  E6_100: BigNumber.from(10).pow(6).mul(100),
  E6_1000: BigNumber.from(10).pow(6).mul(1000),
  E6_10000: BigNumber.from(10).pow(6).mul(10000),
  E18_05: BigNumber.from(10).pow(18).div(2),
  E18_1: BigNumber.from(10).pow(18), // 1e18
  E18_3: BigNumber.from(10).pow(18).mul(3), // 3e18
  E18_10: BigNumber.from(10).pow(18).mul(10), // 10e18
  E18_12: BigNumber.from(10).pow(18).mul(12), // 12e18
  E18_13: BigNumber.from(10).pow(18).mul(13), // 13e18
  E18_50: BigNumber.from(10).pow(18).mul(50), // 50e18
  E18_100: BigNumber.from(10).pow(18).mul(100), // 100e18
  E18_200: BigNumber.from(10).pow(18).mul(200),
  E18_500: BigNumber.from(10).pow(18).mul(500),
  E18_1000: BigNumber.from(10).pow(18).mul(1000), // 1000e18
  E18_6000: BigNumber.from(10).pow(18).mul(6000),
  E18_7500: BigNumber.from(10).pow(18).mul(7500),
  E18_10000: BigNumber.from(10).pow(18).mul(10000), // 1000e18
  E18_1000000: BigNumber.from(10).pow(18).mul(1000000),
  ZERO_ADDRESS: '0x0000000000000000000000000000000000000000',
  DAY: BigNumber.from(60).mul(60).mul(24),
  bigMin,
  randomBigNum,
  getVal,
};