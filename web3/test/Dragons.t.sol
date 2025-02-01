// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Dragons} from "../src/Dragons.sol";

contract DragonsTest is Test {
    Dragons game;

    uint256 minterPrivateKey = 0x1337;
    address minter = vm.addr(minterPrivateKey);

    function setUp() public {
        game = new Dragons();
    }

    function test_deployment() public {
        assertEq(game.LastDragon(), 0);
        assertEq(game.CurrentDragon(), 0);
        assertEq(game.LastDragonSlainAt(), 0);
        assertEq(game.LastDragonMintPrice(), 0);
    }

    function test_mint_first_dragon() public {
        (uint256 nextDragon, uint256 nextDragonMintPrice) = game.nextDragonMintPrice(block.timestamp);
        assertEq(nextDragonMintPrice, 20000 ether);
        assertEq(nextDragon, 1);

        vm.deal(minter, nextDragonMintPrice + 100 ether);

        uint256 mintPrice = nextDragonMintPrice + 1 ether;

        uint256 gameBalance0 = address(game).balance;
        uint256 minterBalance0 = minter.balance;
        assertEq(game.totalSupply(), 0);
        assertEq(game.LastDragon(), 0);
        assertEq(game.CurrentDragon(), 0);
        assertEq(game.LastDragonSlainAt(), 0);
        assertEq(game.LastDragonMintPrice(), 0);

        vm.startPrank(minter);
        uint256 newDragon = game.mint{value: mintPrice}();
        vm.stopPrank();

        assertEq(address(game).balance, gameBalance0 + mintPrice);
        assertEq(minter.balance, minterBalance0 - mintPrice);
        assertEq(game.totalSupply(), 1);
        assertEq(game.ownerOf(newDragon), address(game));
        assertEq(game.LastDragon(), 0);
        assertEq(game.CurrentDragon(), newDragon);
        assertEq(game.LastDragonSlainAt(), 0);
        assertEq(game.LastDragonMintPrice(), mintPrice);
    }
}
