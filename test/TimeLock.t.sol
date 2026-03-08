//SPDX-License-Identifier:MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {console} from "forge-std/console.sol";
import {NotOwner, TimeNotPassed} from "../src/Errors.sol";

contract test is Test {
    //dummy addresses
    address bob = makeAddr("bob");
    address owner = makeAddr("owner");
    TimeLock public timeLock;

    function setUp() public {
        vm.deal(owner, 100 ether);

        vm.prank(owner);
        timeLock = new TimeLock(); //deploy timelock contract and pass contract to timeLock
        console.log(msg.sender);

        vm.deal(bob, type(uint256).max);
        vm.deal(address(this), 100 ether);
    }

    // --BASIC tests--
    function testDepositEth() public {
        vm.expectRevert(); // going to fail, must send >=0.1 ether
        timeLock.depositEth{value: 1e16}();

        //send 0.1 eth
        timeLock.depositEth{value: 1e17}();
    }

    function testWithdrawUnlockedEth() public {
        vm.prank(bob);
        timeLock.depositEth{value: 1 ether}();

        vm.expectRevert();
        timeLock.withdrawUnlockedEth(); //going to fail as time has not been passed yet

        //withdraw balance as bob
        vm.warp(1 weeks + 1 seconds); //
        vm.prank(bob);
        timeLock.withdrawUnlockedEth();

        //try to withdraw balance by bob again
        vm.prank(bob);
        vm.expectRevert();
        timeLock.withdrawUnlockedEth();
    }

    //function to check owner's emergency withdraw is working perfectly
    function testEmergencyWithdraw() public {
        uint256 depositAmount = 10 ether;

        vm.startPrank(owner);
        timeLock.depositEth{value: depositAmount}();
        timeLock.emergencyWithdraw(); //owner request to withdraw
        vm.stopPrank();
        assertEq(timeLock.ownerEmergencyWithdrawAmount(), depositAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                TimeNotPassed.selector,
                "Withdrawn time not reached"
            )
        );
        vm.prank(owner);
        timeLock.emergencyWithdraw(); //REVERT : owner to withdraw before 1 day
        assertEq(timeLock.ownerEmergencyWithdrawAmount(), depositAmount);

        vm.expectRevert(NotOwner.selector);
        vm.prank(bob);
        timeLock.emergencyWithdraw(); //REVERT: bob(not owner) tries to withdraw before 1 day
        assertEq(timeLock.ownerEmergencyWithdrawAmount(), depositAmount);

        vm.warp(1 days + block.timestamp); // Teleport after 1 day
        vm.prank(bob);
        vm.expectRevert(NotOwner.selector);
        timeLock.emergencyWithdraw(); //REVERT: bob try to withdraw after 1 day
        assertEq(timeLock.ownerEmergencyWithdrawAmount(), depositAmount);

        vm.prank(owner);
        timeLock.emergencyWithdraw(); //owner tries to withdraw after 1 day
        assertEq(timeLock.ownerEmergencyWithdrawAmount(), 0);
    }

    function testWeightedAverage() public {
        vm.prank(bob);
        timeLock.depositEth{value: 1 ether}();

        vm.warp(2 days); //go 2 days ahead
        vm.prank(bob);
        timeLock.depositEth{value: 1 ether}();

        (uint256 timeStamp, ) = timeLock.depositors(bob);

        assertEq((1 weeks + 1 weeks + 2 days) / 2, timeStamp); //timestamp will be 1 week (cooldown) + 1 week( current timestamp left) + 2 days completed / 2 ether deposit
    }

    function testFuzz_WithdrawEarly(uint256 balanceToDeposit) public {
        //Use MulDiv library for deposit more than
        balanceToDeposit = bound(balanceToDeposit, 1 wei, 1200 ether);

        vm.startPrank(bob);
        if (balanceToDeposit < 0.1 ether) vm.skip(true); //if balanceToDeposit is less than minimum deposit amount, then skip whole test for the given balanceToDeposit
        timeLock.depositEth{value: balanceToDeposit}(); // ~ Deposited
        uint256 beforeWithdrawBobBalance = bob.balance;

        (, uint256 depositBalance) = timeLock.depositors(bob);
        uint256 balanceAvailableToWithdraw = (depositBalance * 4) / 5;
        console.log(balanceAvailableToWithdraw);

        timeLock.withdrawEarly(); // ~ Withdraw early;
        uint256 afterWithdrawBobBalance = bob.balance;
        (, uint256 afterBalance) = timeLock.depositors(bob);
        uint256 penaltyFee = timeLock.penaltyFeeAccumulated();
        vm.stopPrank();

        // --- Assertion ---
        console.log("done1");

        assertEq(depositBalance, afterBalance + balanceToDeposit);
        console.log("done2");

        assertEq(
            beforeWithdrawBobBalance + ((depositBalance * 4) / 5),
            afterWithdrawBobBalance
        );
        console.log("done3");

        assertEq(depositBalance - balanceAvailableToWithdraw, penaltyFee); // 20% => 100% - 20%
    }

    //testing it should calculate weighted timestamp perfectly, no matter what and when amount deposited.
    function testFuzz_Weightedtimestamp(
        uint256 amount1,
        uint256 amount2,
        uint256 timeJump
    ) public {
        amount1 = bound(amount1, 1 ether, 1000 ether);
        amount2 = bound(amount2, 1 ether, 1000 ether);
        vm.assume(timeJump > 1 days && timeJump < 365 days);
        vm.prank(bob);
        timeLock.depositEth{value: amount1}();

        //BEFORE 2nd deposit:
        (uint256 timestamp, uint256 balance) = timeLock.depositors(bob);

        uint256 beforeBalance = balance;
        uint256 beforeTimestamp = timestamp;

        //TIME TRAVEL => timeJump
        vm.warp(timeJump + block.timestamp); //go 2 days ahead
        vm.prank(bob);
        timeLock.depositEth{value: amount2}();

        //AFTER 2nd deposit:
        (uint256 timeStamp, ) = timeLock.depositors(bob);
        uint256 newTotalBalance = amount2 + amount1;

        uint256 weightedTimestamp = ((beforeBalance * beforeTimestamp) +
            (amount2 * (block.timestamp + 1 weeks))) / (newTotalBalance);

        assertEq(weightedTimestamp, timeStamp); //timestamp will be 1 week (cooldown) + 1 week( current timestamp left) + 2 days completed / 2 ether deposit
    }

    receive() external payable {}
}
