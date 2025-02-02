// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC721 } from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import { IERC721 } from "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import { ERC721Enumerable } from "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import { IERC721Enumerable } from "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import { IERC721Metadata } from "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { IStaker } from "../lib/protocol/web3/contracts/interfaces/IStaker.sol";

/**
 * @notice Dragons implements the game mechanics for Slay the Dragon!, a permissionless game.
 * @notice Dragons is an ERC721 contract and NFTs on this contract represent Dragons. The owner of a Dragon
 * has access to its Hoard.
 */
contract Dragons is ERC721Enumerable {
    error OneDragonAtATime();
    error InsufficientValueForMint();
    error InvalidMintTime(uint256 lowerBound);

    uint256 public constant SECONDS_PER_DAY = 86400;

    uint256 public CurrentDragon;
    uint256 public LastDragon;
    uint256 public LastDragonSlainAt;
    uint256 public LastDragonMintPrice;

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

    function mint() public payable returns (uint256) {
        // The "nextDragonMintPrice" call also checks that the next dragon can be minted. If it cannot, that function call reverts the entire transaction.
        (uint256 nextDragon, uint256 requiredValue) = nextDragonMintPrice(block.timestamp);
        if (msg.value < requiredValue) {
            revert InsufficientValueForMint();
        }

        CurrentDragon = nextDragon;
        LastDragonMintPrice = msg.value;

        _mint(address(this), nextDragon);

        return nextDragon;
    }
}
