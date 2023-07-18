const { expect } = require('chai');
const setup = require('../fixtures');
const { time } = require('@nomicfoundation/hardhat-network-helpers');
const C = require('../constants');
const { BigNumber } = require('ethers');

const revokeTests = (voting, params) => {
  let s, admin, a, b, c, d, hedgey, token, dai, usdc;
  let amount, start, cliff, period, rate, end;
  it('mints a plan and the admin revokes the plan before any redemption', async () => {
    s = await setup();
    hedgey = voting ? s.voteVest : s.vest;
    admin = s.admin;
    a = s.a;
    b = s.b;
    c = s.c;
    d = s.d;
    token = s.token;
    dai = s.dai;
    usdc = s.usdc;
    await token.approve(hedgey.address, C.E18_1000000.mul(1000));
    await dai.approve(hedgey.address, C.E18_1000000.mul(1000));
    await usdc.approve(hedgey.address, C.E18_1000000.mul(1000));
    let now = await time.latest();
    amount = params.amount;
    period = params.period;
    rate = params.rate;
    start = BigNumber.from(now).add(params.start);
    cliff = BigNumber.from(start).add(params.cliff);
    end = C.planEnd(start, amount, rate, period);
    const preAdminBal = await token.balanceOf(admin.address);
    await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period, admin.address, true);
    expect(await hedgey.revokePlans(['1']))
      .to.emit('PlanRevoked')
      .withArgs('1', 0, amount);
    expect(await token.balanceOf(admin.address)).to.eq(preAdminBal);
    expect(await token.balanceOf(hedgey.address)).to.eq(0);
    expect(await token.balanceOf(a.address)).to.eq(0);
    expect((await hedgey.plans('1')).amount).to.eq(0);
    expect((await hedgey.plans('1')).start).to.eq(0);
    expect((await hedgey.plans('1')).cliff).to.eq(0);
    expect((await hedgey.plans('1')).rate).to.eq(0);
    expect((await hedgey.plans('1')).period).to.eq(0);
    expect((await hedgey.plans('1')).token).to.eq(C.ZERO_ADDRESS);
    expect(await hedgey.balanceOf(a.address)).to.eq(0);
    await expect(hedgey.ownerOf('1')).to.be.reverted;
  });
  it('revokes a plan that has been partially redeemed', async () => {
    await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period, admin.address, true);
    // move forward in time to the cliff
    await time.increaseTo(cliff);
    let now = BigNumber.from(await time.latest());
    let check = C.balanceAtTime(start, cliff, amount, rate, period, now.add(2), now.add(2));
    let preBal = await token.balanceOf(admin.address);
    await hedgey.connect(a).redeemAllPlans();
    expect(await hedgey.revokePlans(['2']))
      .to.emit('Planrevoked')
      .withArgs('2', check.balance, check.remainder);
    expect(await token.balanceOf(a.address)).to.eq(check.balance);
    expect(await token.balanceOf(admin.address)).to.eq(preBal.add(amount).sub(check.balance));
    expect(check.balance.add(check.remainder)).to.eq(amount);
  });
  it('revokes a plan that hasnt been redeemed but has partially vested', async () => {
    // token 3
    let now = BigNumber.from(await time.latest());
    await hedgey.createPlan(b.address, token.address, amount, start, cliff, rate, period, admin.address, true);
    let check = C.balanceAtTime(start, cliff, amount, rate, period, now.add(2), now.add(2));
    expect(await hedgey.revokePlans(['3']))
      .to.emit('PlanRevoked')
      .withArgs('3', check.balance, check.remainder);
    expect(await token.balanceOf(b.address)).to.eq(check.balance);
  });
  it('revokes multiple plans for the same beneficiary and different beneficiaries', async () => {
    let plan4 = await hedgey.createPlan(
      b.address,
      dai.address,
      amount,
      start,
      cliff,
      rate,
      period,
      admin.address,
      true
    );
    let plan5 = await hedgey.createPlan(
      b.address,
      dai.address,
      amount,
      start,
      cliff,
      rate,
      period,
      admin.address,
      true
    );
    let plan6 = await hedgey.createPlan(
      b.address,
      dai.address,
      amount,
      start,
      cliff,
      rate,
      period,
      admin.address,
      true
    );

    let plan7 = await hedgey.createPlan(
      a.address,
      usdc.address,
      amount,
      start,
      cliff,
      rate,
      period,
      admin.address,
      true
    );
    let plan8 = await hedgey.createPlan(
      b.address,
      usdc.address,
      amount,
      start,
      cliff,
      rate,
      period,
      admin.address,
      true
    );
    let plan9 = await hedgey.createPlan(
      c.address,
      usdc.address,
      amount,
      start,
      cliff,
      rate,
      period,
      admin.address,
      true
    );
    let plan10 = await hedgey.createPlan(
      d.address,
      usdc.address,
      amount,
      start,
      cliff,
      rate,
      period,
      admin.address,
      true
    );

    let now = BigNumber.from(await time.latest());
    let check = C.balanceAtTime(start, cliff, amount, rate, period, now.add(1), now.add(1));
    let preDai = await dai.balanceOf(admin.address);
    await hedgey.revokePlans(['4', '5', '6']);
    expect(await dai.balanceOf(b.address)).to.eq(check.balance.mul(3));
    expect(await dai.balanceOf(admin.address)).to.eq(preDai.add(check.remainder.mul(3)));
    now = BigNumber.from(await time.latest());
    let preUsdc = await usdc.balanceOf(admin.address);
    let _check = C.balanceAtTime(start, cliff, amount, rate, period, now.add(1), now.add(1));
    await hedgey.revokePlans(['7', '8', '9', '10']);
    expect(await usdc.balanceOf(a.address)).to.eq(_check.balance);
    expect(await usdc.balanceOf(b.address)).to.eq(_check.balance);
    expect(await usdc.balanceOf(c.address)).to.eq(_check.balance);
    expect(await usdc.balanceOf(d.address)).to.eq(_check.balance);
    expect(await usdc.balanceOf(admin.address)).to.eq(preUsdc.add(_check.remainder.mul(4)));
  });
  it('holder creates a voting vault, and then the plan is revoked', async () => {
    let _s = await setup();
    let _hedgey = _s.voteVest;
    let _dai = _s.dai;
    let _admin = _s.admin;
    let _a = _s.a;
    await _dai.approve(_hedgey.address, C.E18_1000000);
    let preDai = await _dai.balanceOf(_admin.address);
    await _hedgey.createPlan(_a.address, _dai.address, amount, start, cliff, rate, period, _admin.address, true);
    let tx = await _hedgey.connect(_a).setupVoting('1');
    const votingVault = (await tx.wait()).events[3].args.vaultAddress;
    expect(await _dai.balanceOf(votingVault)).to.eq(amount);
    let now = BigNumber.from(await time.latest());
    let check = C.balanceAtTime(start, cliff, amount, rate, period, now.add(1), now.add(1));
    await _hedgey.revokePlans(['1']);
    expect(await _dai.balanceOf(_a.address)).to.eq(check.balance);
    expect(await _dai.balanceOf(votingVault)).to.eq(0);
    expect(await _dai.balanceOf(_hedgey.address)).to.eq(0);
    expect(await _dai.balanceOf(_admin.address)).to.eq(preDai.sub(check.balance));
  });
  it('transfers a plan on behalf of a holder and then revokes it', async () => {
    await hedgey.createPlan(b.address, usdc.address, amount, start, cliff, rate, period, admin.address, true);
    await hedgey.transferFrom(b.address, d.address, '11');
    let preBUSDC = await usdc.balanceOf(b.address);
    let preDUSDC = await usdc.balanceOf(d.address);
    let now = BigNumber.from(await time.latest());
    let check = C.balanceAtTime(start, cliff, amount, rate, period, now.add(1), now.add(1));
    expect(await hedgey.revokePlans(['11']))
      .to.emit('PlanRevoked')
      .withArgs('11', check.balance, check.remainder);
    expect(await usdc.balanceOf(b.address)).to.eq(preBUSDC);
    expect(await usdc.balanceOf(d.address)).to.eq(preDUSDC.add(check.balance));
  });
  it('vesting admin changes to a new address and then revokes the plan', async () => {
    await hedgey.createPlan(b.address, usdc.address, amount, start, cliff, rate, period, admin.address, true);
    expect(await hedgey.changeVestingPlanAdmin('12', d.address))
      .to.emit('VestingPlanAdminChanged')
      .withArgs('12', d.address);
    await hedgey.connect(d).revokePlans(['12']);
  });
  it('revokes a plan in the future', async () => {
    let now = BigNumber.from(await time.latest());
    start = now;
    cliff = start;
    const tx = await hedgey.createPlan(
      d.address,
      token.address,
      amount,
      start,
      cliff,
      rate,
      period,
      admin.address,
      true
    );
    // plan 13
    await time.increase(period.mul(5));
    now = BigNumber.from(await time.latest());
    const balanceCheck = C.balanceAtTime(start, cliff, amount, rate, period, now.add(1), now.add(period));
    expect(await hedgey.futureRevokePlans(['13'], now.add(period)))
      .to.emit('PlanRevoked')
      .withArgs('13', balanceCheck.balance, balanceCheck.remainder);
  });
  it('revokes a plan before it has started', async () => {
    let now = BigNumber.from(await time.latest());
    start = now.add(C.WEEK);
    cliff = start.add(params.cliff);
    await hedgey.createPlan(d.address, token.address, amount, start, cliff, rate, period, admin.address, true);
    // plan 14
    expect(await hedgey.connect(admin).revokePlans(['14']))
      .to.emit('PlanRevoked')
      .withArgs('14', 0, amount);
  });
};

const revokeErrorTests = (voting) => {
  let s, admin, a, b, c, d, hedgey, token;
  let amount, start, cliff, period, rate, end;
  it('reverts if the function caller is not the vesting admin', async () => {
    s = await setup();
    hedgey = voting ? s.voteVest : s.vest;
    admin = s.admin;
    a = s.a;
    b = s.b;
    c = s.c;
    d = s.d;
    token = s.token;
    dai = s.dai;
    usdc = s.usdc;
    await token.approve(hedgey.address, C.E18_1000000);
    await dai.approve(hedgey.address, C.E18_1000000);
    await usdc.approve(hedgey.address, C.E18_1000000);
    let now = BigNumber.from(await time.latest());
    amount = C.E18_1000;
    period = C.DAY;
    rate = C.E18_1;
    start = now;
    cliff = now.add(C.DAY);
    end = C.planEnd(start, amount, rate, period);
    await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period, admin.address, true);
    await expect(hedgey.connect(a).revokePlans(['1'])).to.be.revertedWith('!vestingAdmin');
    await expect(hedgey.connect(b).revokePlans(['1'])).to.be.revertedWith('!vestingAdmin');
  });
  it('reverts if the plan has already been fully redeemed', async () => {
    await time.increaseTo(end);
    await hedgey.connect(a).redeemAllPlans();
    await expect(hedgey.revokePlans(['1'])).to.be.revertedWith('!vestingAdmin');
  });
  it('reverts if the plan has already been revoked', async () => {
    let now = BigNumber.from(await time.latest());
    start = now;
    cliff = now.add(C.DAY);
    end = C.planEnd(start, amount, rate, period);
    await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period, admin.address, true);
    await hedgey.revokePlans(['2']);
    await expect(hedgey.revokePlans(['2'])).to.be.revertedWith('!vestingAdmin');
  });
  it('reverts if the plan is fully vested but not yet redeemed', async () => {
    let now = BigNumber.from(await time.latest());
    start = now;
    cliff = now.add(C.DAY);
    end = C.planEnd(start, amount, rate, period);
    await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period, admin.address, true);
    await time.increaseTo(end);
    await expect(hedgey.revokePlans(['3'])).to.be.revertedWith('!Remainder');
  });
  it('reverts when transferring if the boolean is not true', async () => {
    let now = BigNumber.from(await time.latest());
    start = now;
    cliff = now.add(C.DAY);
    await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period, admin.address, false);
    await expect(hedgey.transferFrom(a.address, b.address, '4')).to.be.revertedWith('!transferrable');
  });
  it('reverts when transferring if the function caller is not the admin', async () => {
    let now = BigNumber.from(await time.latest());
    start = now;
    cliff = now.add(C.DAY);
    await hedgey.createPlan(a.address, token.address, amount, start, cliff, rate, period, admin.address, true);
    await expect(hedgey.connect(a).transferFrom(a.address, b.address, '5')).to.be.revertedWith('!vestingAdmin');
  });
  it('reverts when transferring if the admin transfers the plan to themself', async () => {
    await expect(hedgey.transferFrom(a.address, admin.address, '5')).to.be.revertedWith('!transfer to admin');
  });
  it('reverts if the admin tries to change to the holder of the plan', async () => {
    await expect(hedgey.changeVestingPlanAdmin('5', a.address)).to.be.revertedWith('!planOwner');
  });
  it('reverts if the future revoke time is in the past, or if the future date is at full vesting', async () => {
    let now = BigNumber.from(await time.latest());
    amount = C.E18_1000;
    period = C.DAY;
    rate = C.E18_1;
    start = now;
    cliff = now;
    end = C.planEnd(start, amount, rate, period);
    const tx = await hedgey.createPlan(
      a.address,
      token.address,
      amount,
      start,
      cliff,
      rate,
      period,
      admin.address,
      true
    );
    const events = (await tx.wait()).events;
    const planId = events[events.length - 1].args.id;
    await expect(hedgey.connect(admin).futureRevokePlans([planId], now.sub(C.ONE))).to.be.revertedWith('!past revoke');
    await time.increase(period);
    now = BigNumber.from(await time.latest());
    await expect(hedgey.connect(admin).futureRevokePlans([planId], now.sub(C.ONE))).to.be.revertedWith('!past revoke');
    await expect(hedgey.connect(admin).futureRevokePlans([planId], end)).to.be.revertedWith('!Remainder');
  });
};

module.exports = {
  revokeTests,
  revokeErrorTests,
};
