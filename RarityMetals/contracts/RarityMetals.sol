// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC1155/extensions/ERC1155Supply.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/token/ERC721/IERC721.sol';
import 'OpenZeppelin/openzeppelin-contracts@4.3.0/contracts/proxy/utils/Initializable.sol';

import './Base64.sol';
import './Strings.sol';

/// @title Provably Rare metals
/// @author Sorawit Suriyakarn (swit.eth / https://twitter.com/nomorebear)
contract ProvablyRareMetal is Initializable, ERC1155Supply {
  event Create(uint indexed kind);
  event Mine(address indexed miner, uint indexed kind);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  string public name;

  struct Metal {
    string name; // Metal name
    string color; // Metal color
    bytes32 entropy; // Additional mining entropy. bytes32(0) means can't mine.
    uint difficulty; // Current difficulity level. Must be non decreasing
    uint metalsPerMine; // Amount of metals to distribute per mine
    uint multiplier; // Difficulty multiplier times 1e4. Must be between 1e4 and 1e10
    address crafter; // Address that can craft metals
    address manager; // Current metal manager
    address pendingManager; // Pending metal manager to be transferred to
  }

  uint private lock;
  address public owner;
  mapping(uint => Metal) public metals;
  mapping(address => uint) public nonce;
  uint public metalCount;
  uint public maxMetalCount;

  constructor() ERC1155('METAL') {}

  modifier nonReentrant() {
    require(lock == 1, '!lock');
    lock = 2;
    _;
    lock = 1;
  }

  modifier onlyOwner() {
    require(owner == msg.sender, '!owner');
    _;
  }

  /// @dev Initializes the contract.
  function initialize(uint _maxMetalCount) external initializer {
    name = 'Provably Rare Metal';
    lock = 1;
    owner = msg.sender;
    maxMetalCount = _maxMetalCount;
    emit OwnershipTransferred(address(0), msg.sender);
  }

  /// @dev Transfers owner.
  /// @param _owner The new owner.
  function transferOwnership(address _owner) external onlyOwner {
    owner = _owner;
    emit OwnershipTransferred(msg.sender, _owner);
  }

  /// @dev Updates max metal count in the system.
  function setMaxmetalCount(uint _maxMetalCount) external onlyOwner {
    require(_maxMetalCount >= metalCount, 'bad value');
    maxMetalCount = _maxMetalCount;
  }

  /// @dev Creates a new metal type. The manager can craft a portion of metals + can premine
  function create(
    string calldata name,
    string calldata color,
    uint difficulty,
    uint metalsPerMine,
    uint multiplier,
    address crafter,
    address manager
  ) external returns (uint) {
    require(metalCount < maxMetalCount, 'reach max metal');
    require(difficulty > 0 && difficulty <= 2**128, 'bad difficulty');
    require(metalsPerMine > 0 && metalsPerMine <= 1e6, 'bad metals per mine');
    require(multiplier >= 1e4 && multiplier <= 1e10, 'bad multiplier');
    require(manager != address(0), 'bad manager');
    return _create(name, color, difficulty, metalsPerMine, multiplier, crafter, manager);
  }

  /// @dev Mines new metalstones. Puts kind you want to mine + your salt and tests your luck!
  function mine(uint kind, uint salt) external nonReentrant {
    uint val = luck(kind, salt);
    nonce[msg.sender]++;
    require(kind < metalCount, 'metal kind not exist');
    uint diff = metals[kind].difficulty;
    require(val <= type(uint).max / diff, 'salt not good enough');
    metals[kind].difficulty = (diff * metals[kind].multiplier) / 10000 + 1;
    _mint(msg.sender, kind, metals[kind].metalsPerMine, '');
  }

  /// @dev Updates metal mining entropy. Can be called by metal manager or crafter.
  function updateEntropy(uint kind, bytes32 entropy) external {
    require(kind < metalCount, 'metal kind not exist');
    require(metals[kind].manager == msg.sender || metals[kind].crafter == msg.sender, 'unauthorized');
    metals[kind].entropy = entropy;
  }

  /// @dev Updates metal metadata info. Must only be called by the metal manager.
  function updateMetalInfo(
    uint kind,
    string calldata name,
    string calldata color
  ) external {
    require(kind < metalCount, 'metal kind not exist');
    require(metals[kind].manager == msg.sender, 'not metal manager');
    metals[kind].name = name;
    metals[kind].color = color;
  }

  /// @dev Updates metal mining information. Must only be called by the metal manager.
  function updateMiningData(
    uint kind,
    uint difficulty,
    uint multiplier,
    uint metalsPerMine
  ) external {
    require(kind < metalCount, 'metal kind not exist');
    require(metals[kind].manager == msg.sender, 'not metal manager');
    require(difficulty > 0 && difficulty <= 2**128, 'bad difficulty');
    require(multiplier >= 1e4 && multiplier <= 1e10, 'bad multiplier');
    require(metalsPerMine > 0 && metalsPerMine <= 1e6, 'bad metals per mine');
    metals[kind].difficulty = difficulty;
    metals[kind].multiplier = multiplier;
    metals[kind].metalsPerMine = metalsPerMine;
  }

  /// @dev Renounce manametalent ownership for the given metal kinds.
  function renounceManager(uint[] calldata kinds) external {
    for (uint idx = 0; idx < kinds.length; idx++) {
      uint kind = kinds[idx];
      require(kind < metalCount, 'metal kind not exist');
      require(metals[kind].manager == msg.sender, 'not metal manager');
      metals[kind].manager = address(0);
      metals[kind].pendingManager = address(0);
    }
  }

  /// @dev Updates metal crafter. Must only be called by the metal manager.
  function updateCrafter(uint[] calldata kinds, address crafter) external {
    for (uint idx = 0; idx < kinds.length; idx++) {
      uint kind = kinds[idx];
      require(kind < metalCount, 'metal kind not exist');
      require(metals[kind].manager == msg.sender, 'not metal manager');
      metals[kind].crafter = crafter;
    }
  }

  /// @dev Transfers manametalent ownership for the given metal kinds to another address.
  function transferManager(uint[] calldata kinds, address to) external {
    for (uint idx = 0; idx < kinds.length; idx++) {
      uint kind = kinds[idx];
      require(kind < metalCount, 'metal kind not exist');
      require(metals[kind].manager == msg.sender, 'not metal manager');
      metals[kind].pendingManager = to;
    }
  }

  /// @dev Accepts manametalent position for the given metal kinds.
  function acceptManager(uint[] calldata kinds) external {
    for (uint idx = 0; idx < kinds.length; idx++) {
      uint kind = kinds[idx];
      require(kind < metalCount, 'metal kind not exist');
      require(metals[kind].pendingManager == msg.sender, 'not pending manager');
      metals[kind].pendingManager = address(0);
      metals[kind].manager = msg.sender;
    }
  }

  /// @dev Mints metals by crafter. Hopefully, crafter is a good guy. Craft metalsPerMine if amount = 0.
  function craft(
    uint kind,
    uint amount,
    address to
  ) external nonReentrant {
    require(kind < metalCount, 'metal kind not exist');
    require(metals[kind].crafter == msg.sender, 'not metal crafter');
    uint realAmount = amount == 0 ? metals[kind].metalsPerMine : amount;
    _mint(to, kind, realAmount, '');
  }

  /// @dev Returns your luck given salt and metal kind. The smaller the value, the more success chance.
  function luck(uint kind, uint salt) public view returns (uint) {
    require(kind < metalCount, 'metal kind not exist');
    bytes32 entropy = metals[kind].entropy;
    require(entropy != bytes32(0), 'no entropy');
    bytes memory data = abi.encodePacked(
      block.chainid,
      entropy,
      address(this),
      msg.sender,
      kind,
      nonce[msg.sender],
      salt
    );
    return uint(keccak256(data));
  }

  /// @dev Internal function for creating a new metal kind
  function _create(
    string memory metalName,
    string memory color,
    uint difficulty,
    uint metalsPerMine,
    uint multiplier,
    address crafter,
    address manager
  ) internal returns (uint) {
    uint kind = metalCount++;
    metals[kind] = Metal({
      name: metalName,
      color: color,
      entropy: bytes32(0),
      difficulty: difficulty,
      metalsPerMine: metalsPerMine,
      multiplier: multiplier,
      crafter: crafter,
      manager: manager,
      pendingManager: address(0)
    });
    emit Create(kind);
    return kind;
  }

  // prettier-ignore
  function uri(uint kind) public view override returns (string memory) {
    require(kind < metalCount, 'metal kind not exist');
    string memory metalName = string(abi.encodePacked(metals[kind].name, ' #', Strings.toString(kind)));
    string memory color = metals[kind].color;
    string memory output = string(abi.encodePacked(
      '<svg id="Layer_1" x="0px" y="0px" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1080" width="350" height="400"><rect x="0" y="0" width="1080" height="1080" fill="#1a1a1a"/><svg id="Layer_1" x="350" y="350" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1080 1080" width="350" height="400"><g transform="translate(0 -25)"><g><polygon class="st0" fill="',
      color,
      '" points="679.25,58.27 400.75,58.27 203.82,255.2 203.82,824.8 400.75,1021.73 679.25,1021.73 876.18,824.8 876.18,255.2"></polygon><g class="st1" opacity="0.3"><path d="M679.25,58.27h-278.5L203.82,255.2v569.6l196.93,196.93h278.5L876.18,824.8V255.2L679.25,58.27z M739.56,709.06 l-116.9,116.9H457.34l-116.9-116.9V370.94l116.9-116.9h165.32l116.9,116.9V709.06z"></path></g><g><g><polygon class="st2" fill="none" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" points="679.25,58.27 400.75,58.27 203.82,255.2 203.82,824.8 400.75,1021.73 679.25,1021.73 876.18,824.8  876.18,255.2"></polygon><polygon fill="',
      color,
      '" class="st2" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" points="622.66,254.04 457.34,254.04 340.44,370.94 340.44,709.06 457.34,825.96 622.66,825.96  739.56,709.06 739.56,370.94"></polygon><line class="st2" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" x1="400.75" y1="58.27" x2="457.34" y2="254.04"></line><line class="st2" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" x1="679.25" y1="58.27" x2="622.66" y2="254.04"></line><line class="st2" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" x1="203.82" y1="255.2" x2="340.44" y2="370.94"></line><line class="st2" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" x1="739.56" y1="370.94" x2="876.18" y2="255.2"></line><line class="st2" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" x1="739.56" y1="709.06" x2="876.18" y2="824.8"></line><line class="st2" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" x1="622.66" y1="825.96" x2="679.25" y2="1021.73"></line><line class="st2" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" x1="457.34" y1="825.96" x2="400.75" y2="1021.73"></line><line class="st2" stroke-width="10" stroke-miterlimit="10" stroke="#ffffff" x1="340.44" y1="709.06" x2="203.82" y2="824.8"></line></g></g></g></g></svg><text x="50%" y="95%" dominant-baseline="middle" text-anchor="middle" font-size="2.5em" fill="#FFFFFF">',
      metalName,
      '</text></svg>'
    ));
    string memory json = Base64.encode(bytes(string(abi.encodePacked(
      '{ "name": "',
      metalName,
      '", ',
      '"description" : ',
      '"Provably Rare metal is a permissionless on-chain asset for hardcore collectors to mine and collect. metals must be mined with off-chain Proof-of-Work. The higher the metal rarity, the more difficult it is to be found. Stats and other functionalities are intentionally omitted for others to interpret.", ',
      '"image": "data:image/svg+xml;base64,',
      Base64.encode(bytes(output)),
      '"}'
    ))));
    return string(abi.encodePacked('data:application/json;base64,', json));
  }
}