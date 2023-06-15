const C = require('../constants');
const setup = require('../fixtures');
const { expect } = require('chai');
const { time } = require('@nomicfoundation/hardhat-network-helpers');
const { createTree, getProof } = require('../merkleGenerator');
const { ethers } = require('hardhat');
const { v4: uuidv4, parse: uuidParse } = require('uuid');

module.exports = (totalRecipients, nodes) => {
    let owner, a, b, token, claimer;
    let amount, amountA, amountB;
    let id;
    it('Deploys the contracts and creates a merkle tree, uploads the root to the claimer', async () => {
      const s = await setup();
      owner = s.owner;
      a = s.a;
      b = s.b;
      token = s.token;
      claimer = s.claimer;
      let values = [];
      amount = C.ZERO;
      const uuid = uuidv4();
      id = uuidParse(uuid);
      for (let i = 0; i < totalRecipients; i++) {
        let wallet;
        let amt = C.randomBigNum(1000, 1);
        if (i == nodes.nodeA) {
          wallet = a.address;
          amountA = amt;
        } else if (i == nodes.nodeB) {
          wallet = b.address;
          amountB = amt;
        } else {
          wallet = ethers.Wallet.createRandom().address;
        }
        amount = amt.add(amount);
        values.push([wallet, amt]);
      }
      const root = createTree(values, ['address', 'uint256']);
      let now = await time.latest();
      let end = C.YEAR.add(now);
      let campaign = {
        manager: owner.address,
        token: token.address,
        amount,
        end,
        tokenLockup: 0,
        root,
      };
      let lockup = {
        tokenLocker: C.ZERO_ADDRESS,
        rate: 0,
        start: 0,
        cliff: 0,
        period: 0,
      };
      expect(await claimer.createCampaign(id, campaign, lockup, C.ZERO))
        .to.emit('CaimpaignStarted')
        .withArgs(id, campaign);
      expect(await token.balanceOf(claimer.address)).to.equal(amount);
    });
    it('Wallet A claims their tokens', async () => {
      let proof = getProof('./test/trees/tree.json', a.address);
      await claimer.connect(a).claimTokens(id, proof, amountA);
      expect(await token.balanceOf(a.address)).to.equal(amountA);
      expect(await token.balanceOf(claimer.address)).to.equal(amount.sub(amountA));
    });
    it('If Wallet B is part of the claim it will claim tokens, otherwise cannot claim', async () => {
      let proof = getProof('./test/trees/tree.json', b.address);
      console.log(proof);
      if (proof.length > 0) {
        console.log('trying it out');
        await claimer.connect(b).claimTokens(id, proof, amountB);
        expect(await token.balanceOf(b.address)).to.equal(amountB);
        expect(await token.balanceOf(claimer.address)).to.equal(amount.sub(amountA).sub(amountB));
      } else {
        let fakeProof = getProof('./test/trees/tree.json', a.address);
        await expect(claimer.connect(b).claimTokens(id, fakeProof, amountB)).to.be.reverted;
      }
    });
    it('Wallet A cannot claim again', async () => {
      let proof = getProof('./test/trees/tree.json', a.address);
      await expect(claimer.connect(a).claimTokens(id, proof, amountA)).to.be.revertedWith('already claimed');
    });
    it('owner cancels the claim', async () => {
      await claimer.cancelCampaign(id);
      expect(await token.balanceOf(claimer.address)).to.equal(C.ZERO);
    })
  };
  
