// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Airdrop.sol";
import "../src/TestToken.sol";
import "../lib/forge-std/src/console.sol";

contract AirdropTest is Test {
    TestToken token;
    Airdrop airdropContract;
    uint256 createdId;
    uint256 endTime;

    error AirdropNotOver();
    // --- constants ---

    uint256 TOTAL_AMOUNT = 10000e18;
    bytes32 TEST_ROOT =
        0x4c7e31087f7151334bb9499652a93ef434ff30a22ebda06014db534560ca51ed;
    address ADDRESS_BOB = address(1);
    address ADDRESS_JOHN = address(5);
    address VAULT = address(420);
    address MOCK_ADMIN = address(1337);

    function setUp() public {
        airdropContract = new Airdrop();

        vm.prank(MOCK_ADMIN);
        token = new TestToken(
            MOCK_ADMIN,
            address(airdropContract),
            TOTAL_AMOUNT
        );

        // 1 week
        endTime = block.timestamp + (60 * 60 * 24 * 7);

        vm.prank(MOCK_ADMIN);
        createdId = airdropContract.createAirdrop(
            TEST_ROOT,
            TOTAL_AMOUNT,
            address(token),
            0,
            endTime
        );
    }

    function testBobClaim() public {
        bytes32[] memory proofBob = new bytes32[](3);
        uint256 balanceBefore = token.balanceOf(ADDRESS_BOB);

        proofBob[
            0
        ] = 0xd25268843b8ef9c9c17871850b2afbf9ee498256faeb385ac60ac89412bd5e5e;

        proofBob[
            1
        ] = 0xee1f33e1106ad22cc4c93f6fc0b45adc4a33fbf1cd90d160b93d8bd2228704f7;

        proofBob[
            2
        ] = 0x093c85f9d16d74d3324ce734a73e014e50230327ea0b497b950f3deff0aa6502;

        airdropContract.claim(createdId, ADDRESS_BOB, 100, proofBob);
        assertEq(token.balanceOf(ADDRESS_BOB), balanceBefore + 100);
    }

    function testBobAndJohnClaim() public {
        bytes32[] memory proofBob = new bytes32[](3);
        uint256 balanceBefore = token.balanceOf(ADDRESS_BOB);

        proofBob[
            0
        ] = 0xd25268843b8ef9c9c17871850b2afbf9ee498256faeb385ac60ac89412bd5e5e;

        proofBob[
            1
        ] = 0xee1f33e1106ad22cc4c93f6fc0b45adc4a33fbf1cd90d160b93d8bd2228704f7;

        proofBob[
            2
        ] = 0x093c85f9d16d74d3324ce734a73e014e50230327ea0b497b950f3deff0aa6502;

        airdropContract.claim(createdId, ADDRESS_BOB, 100, proofBob);
        assertEq(token.balanceOf(ADDRESS_BOB), balanceBefore + 100);

        bytes32[] memory proofJohn = new bytes32[](1);
        uint256 balanceBeforeJohn = token.balanceOf(ADDRESS_JOHN);

        proofJohn[
            0
        ] = 0x09f3e6a203ecf99913c8cb387620d07a17855a254096ab4f0e2fbdc35ada66c6;

        airdropContract.claim(createdId, ADDRESS_JOHN, 100, proofJohn);
        assertEq(token.balanceOf(ADDRESS_JOHN), balanceBeforeJohn + 100);
    }

    function testFailBobClaim() public {
        bytes32[] memory proofBob = new bytes32[](3);

        proofBob[
            0
        ] = 0xd25268843b8ef9c9c17871850b2afbf9ee498256faeb385ac60ac89412bd5e5e;

        proofBob[
            1
        ] = 0xee1f33e1106ad22cc4c93f6fc0b45adc4a33fbf1cd90d160b93d8bd2228704f7;

        proofBob[
            2
        ] = 0x093c85f9d16d74d3324ce734a73e014e50230327ea0b497b950f3deff0aa6502;

        airdropContract.claim(createdId, ADDRESS_BOB, 100, proofBob);

        // try to claim twice, should fail
        airdropContract.claim(createdId, ADDRESS_BOB, 100, proofBob);
    }

    function testFailBobInvalidProof() public {
        bytes32[] memory proofBob = new bytes32[](3);

        proofBob[
            0
        ] = 0xd25268843b8ef9c9c17871850b2afbf9ee498256faeb385ac60ac89412bd5e5e;

        // elements have been swapped
        proofBob[
            1
        ] = 0x093c85f9d16d74d3324ce734a73e014e50230327ea0b497b950f3deff0aa6502;

        proofBob[
            2
        ] = 0xee1f33e1106ad22cc4c93f6fc0b45adc4a33fbf1cd90d160b93d8bd2228704f7;

        airdropContract.claim(createdId, ADDRESS_BOB, 100, proofBob);
    }

    function testFailCantMintAfterEndTime() public {
        bytes32[] memory proofBob = new bytes32[](3);

        // correct proof
        proofBob[
            0
        ] = 0xd25268843b8ef9c9c17871850b2afbf9ee498256faeb385ac60ac89412bd5e5e;

        proofBob[
            1
        ] = 0xee1f33e1106ad22cc4c93f6fc0b45adc4a33fbf1cd90d160b93d8bd2228704f7;

        proofBob[
            2
        ] = 0x093c85f9d16d74d3324ce734a73e014e50230327ea0b497b950f3deff0aa6502;

        // move time after the airdrop period
        vm.warp(endTime + 100);
        airdropContract.claim(createdId, ADDRESS_BOB, 100, proofBob);
    }

    function testCanOnlyDrainAfterEnd() public {
        vm.expectRevert(AirdropNotOver.selector);
        vm.prank(MOCK_ADMIN);
        airdropContract.drainAirdropFunds(createdId, MOCK_ADMIN);

        vm.warp(endTime + 100);
        vm.prank(MOCK_ADMIN);
        airdropContract.drainAirdropFunds(createdId, MOCK_ADMIN);
    }

    function testCorrectAmountDrained() public {
        bytes32[] memory proofBob = new bytes32[](3);

        proofBob[
            0
        ] = 0xd25268843b8ef9c9c17871850b2afbf9ee498256faeb385ac60ac89412bd5e5e;

        proofBob[
            1
        ] = 0xee1f33e1106ad22cc4c93f6fc0b45adc4a33fbf1cd90d160b93d8bd2228704f7;

        proofBob[
            2
        ] = 0x093c85f9d16d74d3324ce734a73e014e50230327ea0b497b950f3deff0aa6502;

        airdropContract.claim(createdId, ADDRESS_BOB, 100, proofBob);

        bytes32[] memory proofJohn = new bytes32[](1);

        proofJohn[
            0
        ] = 0x09f3e6a203ecf99913c8cb387620d07a17855a254096ab4f0e2fbdc35ada66c6;

        airdropContract.claim(createdId, ADDRESS_JOHN, 100, proofJohn);

        vm.warp(endTime + 100);
        vm.prank(MOCK_ADMIN);
        airdropContract.drainAirdropFunds(createdId, VAULT);
        assertEq(token.balanceOf(VAULT), TOTAL_AMOUNT - 200);
    }

    function testFailInvalidTimesCreateAirdrop() public {
        // 1 week before
        endTime = block.timestamp - (60 * 60 * 24 * 7);

        createdId = airdropContract.createAirdrop(
            TEST_ROOT,
            TOTAL_AMOUNT,
            address(token),
            block.timestamp,
            endTime
        );
    }
}
