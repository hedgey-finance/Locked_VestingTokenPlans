const { expect } = require('chai');
const setup = require('../fixtures');
const { time } = require('@nomicfoundation/hardhat-network-helpers');
const C = require('../constants');
const { BigNumber } = require('ethers');
const { ethers } = require('hardhat');

module.exports = () => {
  let s, admin, a, b, token, lockups, voteLocksup, bl, bvl, vesting, voteVesting;
  let amount, rate, start, cliff, period;
  it('non transferable lockups cannot be transferred', async () => {
    s = await setup();
    admin = s.admin;
    a = s.a;
    b = s.b;
    token = s.token;
    lockups = s.locked;
    voteLocksup = s.voteLocked;
    vesting = s.vest;
    voteVesting = s.voteVest;
    const BL = await ethers.getContractFactory('TokenLockupPlans_Bound');
    bl = await BL.deploy('Bound', 'bd');
    const BVL = await ethers.getContractFactory('VotingTokenLockupPlans_Bound');
    bvl = await BVL.deploy('BoundVoting', 'BVL');
    await token.approve(lockups.address, C.E18_10000);
    await token.approve(voteLocksup.address, C.E18_10000);
    await token.approve(vesting.address, C.E18_10000);
    await token.approve(voteVesting.address, C.E18_10000);
    await token.approve(bl.address, C.E18_10000);
    await token.approve(bvl.address, C.E18_10000);
    amount = C.E18_1000;
    rate = C.E18_1;
    let now = BigNumber.from(await time.latest());
    start = now;
    cliff = now;
    period = C.DAY;
    await bl.createPlan(a.address, token.address, amount, start, cliff, rate, period);
    await bvl.createPlan(a.address, token.address, amount, start, cliff, rate, period);
    await expect(bl.connect(a).transferFrom(a.address, b.address, '1')).to.be.revertedWith('Not transferrable');
    await expect(bvl.connect(a).transferFrom(a.address, b.address, '1')).to.be.revertedWith('Not transferrable');
    await expect(
      bl.connect(a)['safeTransferFrom(address,address,uint256)'](a.address, b.address, '1')
    ).to.be.revertedWith('Not transferrable');
    await expect(
      bvl.connect(a)['safeTransferFrom(address,address,uint256)'](a.address, b.address, '1')
    ).to.be.revertedWith('Not transferrable');
  });
  it('transferable lockups can be transferred', async () => {
    await lockups.createPlan(a.address, token.address, amount, start, cliff, rate, period);
    await voteLocksup.createPlan(a.address, token.address, amount, start, cliff, rate, period);
    await lockups.connect(a).transferFrom(a.address, b.address, '1');
    await voteLocksup.connect(a).transferFrom(a.address, b.address, '1');
    expect(await lockups.ownerOf('1')).to.eq(b.address);
    expect(await voteLocksup.ownerOf('1')).to.eq(b.address);
    await expect(lockups.connect(a).transferFrom(b.address, a.address, '1')).to.be.revertedWith(
      'ERC721: caller is not token owner or approved'
    );
    await expect(voteLocksup.connect(a).transferFrom(b.address, a.address, '1')).to.be.revertedWith(
      'ERC721: caller is not token owner or approved'
    );
  });
  it('vesting contracts cannot be transferred if boolean off', async () => {
    await vesting.createPlan(a.address, token.address, amount, start, cliff, rate, period, admin.address, false);
    await voteVesting.createPlan(a.address, token.address, amount, start, cliff, rate, period, admin.address, false);
    await expect(vesting.transferFrom(a.address, b.address, '1')).to.be.revertedWith('!transferrable');
    await expect(voteVesting.transferFrom(a.address, b.address, '1')).to.be.revertedWith('!transferrable');
  });
  it('vesting contracts can not be transferred to the vesting admin', async () => {
    await vesting.createPlan(a.address, token.address, amount, start, cliff, rate, period, admin.address, true);
    await voteVesting.createPlan(a.address, token.address, amount, start, cliff, rate, period, admin.address, true);
    await expect(vesting.transferFrom(a.address, admin.address, '2')).to.be.revertedWith('!transfer to admin');
    await expect(voteVesting.transferFrom(a.address, admin.address, '2')).to.be.revertedWith('!transfer to admin');
  });
  it('vesting contracts cannot be transferred by the owner of the plan', async () => {
    await expect(vesting.connect(a).transferFrom(a.address, b.address, '2')).to.be.revertedWith('!vestingAdmin');
    await expect(voteVesting.connect(a).transferFrom(a.address, b.address, '2')).to.be.revertedWith('!vestingAdmin');
    await expect(
      vesting.connect(a)['safeTransferFrom(address,address,uint256)'](a.address, b.address, '2')
    ).to.be.revertedWith('!transferrable');
    await expect(
      voteVesting.connect(a)['safeTransferFrom(address,address,uint256)'](a.address, b.address, '2')
    ).to.be.revertedWith('!transferrable');
    await vesting.connect(a).approve(b.address, '1');
    await expect(
      vesting.connect(b)['safeTransferFrom(address,address,uint256)'](a.address, b.address, '1')
    ).to.be.revertedWith('!transferrable');
    await voteVesting.connect(a).approve(b.address, '1');
    await expect(
      voteVesting.connect(b)['safeTransferFrom(address,address,uint256)'](a.address, b.address, '1')
    ).to.be.revertedWith('!transferrable');
  });
};
