// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC721 } from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import { ERC721Enumerable } from "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import { IStaker } from "../lib/protocol/web3/contracts/interfaces/IStaker.sol";

/**
 * @notice Dragons implements the game mechanics for Slay the Dragon!, a permissionless game.
 * @notice Dragons is an ERC721 contract and NFTs on this contract represent Dragons. The owner of a Dragon
 * has access to its Hoard.
 */
contract Dragons is ERC721Enumerable {
    error InvalidColor();
    error OneDragonAtATime();
    error InsufficientValueForMint();
    error InvalidMintTime(uint256 lowerBound);
    error NoLivingDragon();

    event DragonCreated(uint256 indexed dragon, uint256 indexed color, uint256 power);
    event DragonSlain(uint256 indexed dragon, address indexed slayer);

    uint256 public constant SECONDS_PER_DAY = 86400;

    uint256 public constant DRAGON_COLOR_BLACK = 1;
    uint256 public constant DRAGON_COLOR_GREEN = 2;
    uint256 public constant DRAGON_COLOR_BLUE = 3;
    uint256 public constant DRAGON_COLOR_RED = 4;
    uint256 public constant DRAGON_COLOR_WHITE = 5;

    uint256 public CurrentDragon;
    uint256 public LastDragon;
    uint256 public LastDragonSlainAt;
    uint256 public LastDragonMintPrice;

    // Dragon ID => address of slayer.
    // If dragon has not yet been slain, the slayer will be address(0).
    mapping(uint256 => address) public DragonSlainBy;

    // Dragon ID => color of dragon
    // Colors are enumerated by the DRAGON_COLOR_* constants.
    mapping(uint256 => uint256) public DragonColor;

    // Dragon ID => dragon's power level
    // Power level is defined as floor(mint_cost / 400).
    mapping(uint256 => uint256) public DragonPower;

    // Dragon ID => dragon's current hit points
    // Max HP for a dragon is 400*power.
    mapping(uint256 => uint256) public DragonHP;

    constructor() ERC721("Dragons", "DRAGONS") {}

    function _oneDragonAtATime() internal view {
        if (CurrentDragon != LastDragon) {
            revert OneDragonAtATime();
        }
    }

    function nextDragonMintPrice(uint256 mintTime) public view returns (uint256 nextDragonID, uint256 mintPrice) {
        _oneDragonAtATime();

        uint256 auctionStartPrice = 2 * LastDragonMintPrice;
        if (auctionStartPrice < 20000 ether) {
            auctionStartPrice = 20000 ether;
        }

        if (mintTime < LastDragonSlainAt) {
            revert InvalidMintTime(LastDragonSlainAt);
        }
        uint256 daysSinceLastMint = (mintTime - LastDragonSlainAt)/SECONDS_PER_DAY;

        if (daysSinceLastMint * (1000 ether) >= auctionStartPrice - (400 ether)) {
            mintPrice = 400 ether;
        } else {
            mintPrice = auctionStartPrice - (1000 ether) * daysSinceLastMint;
        }

        nextDragonID = CurrentDragon + 1;
    }

    function mint(uint256 color) public payable returns (uint256) {
        // The "nextDragonMintPrice" call also checks that the next dragon can be minted. If it cannot, that function call reverts the entire transaction.
        (uint256 nextDragon, uint256 requiredValue) = nextDragonMintPrice(block.timestamp);
        if (msg.value < requiredValue) {
            revert InsufficientValueForMint();
        }

        CurrentDragon = nextDragon;
        LastDragonMintPrice = msg.value;

        _mint(address(this), nextDragon);

        if (color != DRAGON_COLOR_BLACK && color != DRAGON_COLOR_GREEN && color != DRAGON_COLOR_BLUE && color != DRAGON_COLOR_RED && color != DRAGON_COLOR_WHITE) {
            revert InvalidColor();
        }
        DragonColor[nextDragon] = color;
        DragonPower[nextDragon] = msg.value/(400 ether);
        DragonHP[nextDragon] = DragonPower[nextDragon];

        emit DragonCreated(nextDragon, color, DragonPower[nextDragon]);

        return nextDragon;
    }

    function _slayCurrentDragon(address slayer, bytes memory data) internal {
        if (CurrentDragon == LastDragon) {
            revert NoLivingDragon();
        }

        LastDragon = CurrentDragon;
        LastDragonSlainAt = block.timestamp;
        DragonSlainBy[LastDragon] = slayer;

        _safeTransfer(address(this), slayer, LastDragon, data);

        emit DragonSlain(LastDragon, slayer);
    }
}