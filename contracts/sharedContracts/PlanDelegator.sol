// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';

abstract contract PlanDelegator is ERC721Enumerable {
  // mapping of tokenId to address who can delegate an NFT on behalf of the owner
  /// @dev follows tokenApprovals logic
  mapping(uint256 => address) private _approvedDelegators;

  /// @dev operatorApprovals simialr to ERC721 standards
  mapping(address => mapping(address => bool)) private _approvedOperatorDelegators;

  // events
  event DelegatorApproved(address owner, address delegator, uint256 id);
  event ApprovalForAllDelegation(address owner, address operator, bool approved);

  function approveDelegator(address delegator, uint256 planId) public virtual {
    address owner = ownerOf(planId);
    require(msg.sender == owner || isApprovedForAllDelegation(owner, msg.sender), '!ownerOperator');
    require(delegator != msg.sender, '!self approval');
    _approveDelegator(delegator, planId);
  }

  function approveSpenderDelegator(address spender, uint256 planId) public virtual {
    address owner = ownerOf(planId);
    require(msg.sender == owner || (isApprovedForAllDelegation(owner, msg.sender) && isApprovedForAll(owner, msg.sender)), '!ownerOperator');
    require(spender != msg.sender, '!self approval');
    _approveDelegator(spender, planId);
    _approve(spender, planId);
  }

  function setApprovalForAllDelegation(address operator, bool approved) public virtual {
    _setApprovalForAllDelegation(msg.sender, operator, approved);
  }

  function setApprovalForOperator(address operator, bool approved) public virtual {
    _setApprovalForAllDelegation(msg.sender, operator, approved);
    _setApprovalForAll(msg.sender, operator, approved);
  }

  function _approveDelegator(address delegator, uint256 planId) internal virtual {
    _approvedDelegators[planId] = delegator;
    emit DelegatorApproved(ownerOf(planId), delegator, planId);
  }

  function _setApprovalForAllDelegation(address owner, address operator, bool approved) internal virtual {
    require(owner != operator, '!operator');
    _approvedOperatorDelegators[owner][operator] = approved;
    emit ApprovalForAllDelegation(owner, operator, approved);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 firstTokenId,
    uint256 batchSize
  ) internal virtual override {
    super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    delete _approvedDelegators[firstTokenId];
  }

  function getApprovedDelegator(uint256 planId) public view returns (address) {
    _requireMinted(planId);
    return _approvedDelegators[planId];
  }

  function isApprovedForAllDelegation(address owner, address operator) public view returns (bool) {
    return _approvedOperatorDelegators[owner][operator];
  }

  function _isApprovedDelegatorOrOwner(address delegator, uint256 planId) internal view returns (bool) {
    address owner = ownerOf(planId);
    return (delegator == owner ||
      isApprovedForAllDelegation(owner, delegator) ||
      getApprovedDelegator(planId) == delegator);
  }
}
