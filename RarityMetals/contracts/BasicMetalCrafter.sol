// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/access/Ownable.sol';
import './RarityMetals.sol';

/// @title Basic metal Crafter
/// @author Sorawit Suriyakarn (swit.eth / https://twitter.com/nomorebear)
contract BasicMetalCrafter is Ownable {
  ProvablyRareMetal public immutable METAL;
  mapping(uint => uint) public crafted;

  constructor(ProvablyRaremetalV3 _metal) {
    METAL = _metal;
    _metal.create('Coal', '#30D5C8', 7**2, 64, 10000, address(this), msg.sender);
    _metal.create('Copper', '#EAE0C8', 7**3, 32, 10001, address(this), msg.sender);
    _metal.create('Tin', '#007082', 7**4, 16, 10005, address(this), msg.sender);
    _metal.create('Iron', '#A3C6C2', 7**5, 8, 10010, address(this), msg.sender);
    _metal.create('Silver', '#FFBF00', 7**6, 4, 10030, address(this), msg.sender);
    _metal.create('Platinum', '#034B03', 7**7, 2, 10100, address(this), msg.sender);
    _metal.create('Mithril', '#7FFFD4', 7**8, 1, 10300, address(this), msg.sender);
    _metal.create('Adamant', '#872282', 7**9, 1, 11000, address(this), msg.sender);
    _metal.create('Rune', '#F26722', 7**10, 1, 13000, address(this), msg.sender);
    _metal.create('Dragon', '#21B54B', 7**11, 1, 20000, address(this), msg.sender);
    _metal.create('Orichalcum', '#1E88B4', 7**12, 1, 30000, address(this), msg.sender);
    _metal.create("Raridium", '#660000', 7**13, 1, 50000, address(this), msg.sender);
  }

  /// @dev Creaes more metal
  function create(
    string calldata name,
    string calldata color,
    uint difficulty,
    uint metalsPerMine,
    uint multiplier
  ) external onlyOwner {
    METAL.create(name, color, difficulty, metalsPerMine, multiplier, address(this), msg.sender);
  }

  /// @dev Called once to start mining for the given kinds.
  function start(uint[] calldata kinds) external onlyOwner {
    for (uint idx = 0; idx < kinds.length; idx++) {
      METAL.updateEntropy(kinds[idx], blockhash(block.number - 1));
    }
  }

  /// @dev Called to stop mining for the given kinds.
  function stop(uint[] calldata kinds) external onlyOwner {
    for (uint idx = 0; idx < kinds.length; idx++) {
      METAL.updateEntropy(kinds[idx], bytes32(0));
    }
  }

  /// @dev Called by metal manager to craft metals. Can't craft more than 10% of supply.
  function craft(uint kind, uint amount) external onlyOwner {
    require(amount != 0, 'zero amount craft');
    crafted[kind] += amount;
    METAL.craft(kind, amount, msg.sender);
    require(crafted[kind] <= METAL.totalSupply(kind) / 10, 'too many crafts');
  }
}
