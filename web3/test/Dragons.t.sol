// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC721 } from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

import {Test, console} from "forge-std/Test.sol";

import {Dragons} from "../src/Dragons.sol";

/**
 * MockERC721 is only intended to be used for testing, and should never be used in a production setting.
 */
contract MockERC721 is ERC721 {
    constructor() ERC721("MockERC721", "MOCK") {}

    function mint(address to, uint256 tokenID) external {
        _mint(to, tokenID);
    }

    function burn(uint256 tokenID) external {
        _burn(tokenID);
    }
}

/**
 * TestableDragons is only intended to be used for testing, and should never be used in a production setting.
 */
contract TestableDragons is Dragons {
    function forceSlayCurrentDragon(address slayer, bytes memory data) external {
        _slayCurrentDragon(slayer, data);
    }
}

contract DragonsTest is Test {
    TestableDragons game;
    event DragonCreated(uint256 indexed dragon, uint256 indexed color, uint256 power);
    event DragonSlain(uint256 indexed dragon, address indexed slayer);

    MockERC721 characters1;
    MockERC721 characters2;

    uint256 minterPrivateKey = 0x1337;
    address minter = vm.addr(minterPrivateKey);

    uint256 player1PrivateKey = 0x1338;
    address player1 = vm.addr(player1PrivateKey);

    function setUp() public {
        game = new TestableDragons();
        characters1 = new MockERC721();
        characters2 = new MockERC721();
    }

    function test_deployment() public {
        assertEq(game.name(), "Dragons");
        assertEq(game.symbol(), "DRAGONS");
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
        vm.expectEmit();
        emit DragonCreated(nextDragon, game.DRAGON_COLOR_RED(), mintPrice/(400 ether));
        uint256 newDragon = game.mint{value: mintPrice}(game.DRAGON_COLOR_RED());
        vm.stopPrank();

        assertEq(address(game).balance, gameBalance0 + mintPrice);
        assertEq(minter.balance, minterBalance0 - mintPrice);
        assertEq(game.totalSupply(), 1);
        assertEq(game.ownerOf(newDragon), address(game));
        assertEq(game.LastDragon(), 0);
        assertEq(game.CurrentDragon(), newDragon);
        assertEq(game.LastDragonSlainAt(), 0);
        assertEq(game.LastDragonMintPrice(), mintPrice);
        assertEq(game.DragonColor(newDragon), game.DRAGON_COLOR_RED());
        assertEq(game.DragonPower(newDragon), mintPrice/(400 ether));
        assertEq(game.DragonHP(newDragon), mintPrice/(400 ether));
    }

    function test_one_dragon_at_a_time() public {
        (uint256 nextDragon, uint256 nextDragonMintPrice) = game.nextDragonMintPrice(block.timestamp);
        vm.deal(minter, 3*nextDragonMintPrice);
        assertEq(game.totalSupply(), 0);
        assertEq(nextDragon, 1);

        vm.startPrank(minter);
        game.mint{value: nextDragonMintPrice}(game.DRAGON_COLOR_WHITE());

        vm.expectRevert(Dragons.OneDragonAtATime.selector);
        // 1 - black
        game.mint{value: 2*nextDragonMintPrice}(1);
        vm.stopPrank();
    }

    function test_minting_cost_must_be_paid() public {
        (uint256 nextDragon, uint256 nextDragonMintPrice) = game.nextDragonMintPrice(block.timestamp);
        vm.deal(minter, nextDragonMintPrice);

        vm.startPrank(minter);
        vm.expectRevert(Dragons.InsufficientValueForMint.selector);
        // 2 - green
        game.mint{value: nextDragonMintPrice - 1}(2);
        vm.stopPrank();
    }

    function test_minter_can_exceed_minting_cost() public {
        (uint256 nextDragon, uint256 nextDragonMintPrice) = game.nextDragonMintPrice(block.timestamp);
        vm.deal(minter, nextDragonMintPrice + (400 ether));

        uint256 gameBalance0 = address(game).balance;

        vm.startPrank(minter);
        vm.expectEmit();
        emit DragonCreated(nextDragon, game.DRAGON_COLOR_BLUE(), (nextDragonMintPrice + (400 ether))/(400 ether));
        game.mint{value: nextDragonMintPrice + (400 ether)}(game.DRAGON_COLOR_BLUE());
        vm.stopPrank();

        assertEq(game.ownerOf(nextDragon), address(game));
        assertEq(game.LastDragonMintPrice(), nextDragonMintPrice + (400 ether));
        assertEq(address(game).balance, nextDragonMintPrice + (400 ether));
        assertEq(game.DragonColor(nextDragon), game.DRAGON_COLOR_BLUE());
        assertEq(game.DragonPower(nextDragon), (nextDragonMintPrice + (400 ether))/(400 ether));
        assertEq(game.DragonHP(nextDragon),  (nextDragonMintPrice + (400 ether))/(400 ether));
    }

    function test_mint_price_decay() public {
        uint256 nextDragon;
        uint256 nextDragonMintPrice;

        (nextDragon, nextDragonMintPrice) = game.nextDragonMintPrice(block.timestamp + 0);
        assertEq(nextDragon, 1);
        assertEq(nextDragonMintPrice, 20000 ether);

        (nextDragon, nextDragonMintPrice) = game.nextDragonMintPrice(block.timestamp + game.SECONDS_PER_DAY());
        assertEq(nextDragon, 1);
        assertEq(nextDragonMintPrice, 19000 ether);

        (nextDragon, nextDragonMintPrice) = game.nextDragonMintPrice(block.timestamp + 19*game.SECONDS_PER_DAY());
        assertEq(nextDragon, 1);
        assertEq(nextDragonMintPrice, 1000 ether);

        (nextDragon, nextDragonMintPrice) = game.nextDragonMintPrice(block.timestamp + 20*game.SECONDS_PER_DAY());
        assertEq(nextDragon, 1);
        assertEq(nextDragonMintPrice, 400 ether);

        (nextDragon, nextDragonMintPrice) = game.nextDragonMintPrice(block.timestamp + 100*game.SECONDS_PER_DAY());
        assertEq(nextDragon, 1);
        assertEq(nextDragonMintPrice, 400 ether);
    }

    function test_mint_dragon_after_slaying_previous_dragon() public {
        (uint256 nextDragon, uint256 nextDragonMintPrice) = game.nextDragonMintPrice(block.timestamp);
        vm.deal(minter, 3*nextDragonMintPrice);
        assertEq(game.totalSupply(), 0);
        assertEq(nextDragon, 1);

        // Just warping forward arbitrarily to check setting of LastDragonSlainAt.
        vm.warp(block.timestamp + 193443);

        vm.startPrank(minter);
        game.mint{value: nextDragonMintPrice}(game.DRAGON_COLOR_BLUE());
        assertEq(game.CurrentDragon(), 1);
        assertEq(game.LastDragon(), 0);
        assertEq(game.LastDragonSlainAt(), 0);
        assertEq(game.LastDragonMintPrice(), nextDragonMintPrice);
        assertEq(game.DragonSlainBy(1), address(0));
        assertEq(game.ownerOf(1), address(game));

        game.forceSlayCurrentDragon(player1, "");

        assertEq(game.CurrentDragon(), 1);
        assertEq(game.LastDragon(), 1);
        assertEq(game.LastDragonSlainAt(), block.timestamp);
        assertEq(game.LastDragonMintPrice(), nextDragonMintPrice);
        assertEq(game.DragonSlainBy(1), player1);
        assertEq(game.ownerOf(1), player1);

        game.mint{value: 2*nextDragonMintPrice}(game.DRAGON_COLOR_RED());

        assertEq(game.CurrentDragon(), 2);
        assertEq(game.LastDragon(), 1);
        assertEq(game.LastDragonSlainAt(), block.timestamp);
        assertEq(game.LastDragonMintPrice(), 2*nextDragonMintPrice);
        assertEq(game.DragonSlainBy(1), player1);
        assertEq(game.DragonSlainBy(2), address(0));
        assertEq(game.ownerOf(1), player1);
        assertEq(game.ownerOf(2), address(game));

        vm.stopPrank();
    }
}
