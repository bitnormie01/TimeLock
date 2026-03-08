//SPDX-License-Identifier:MIT
pragma solidity ^0.8.30;

//Custom errors:
import {MinimumDeposit, NoDeposit, TimeNotPassed, TransferFailed, NotOwner} from "./Errors.sol";

//Contract to lock(deposit) user eth and withdraw functionality with some cool features (check Readme.md)

contract TimeLock {
    // -------Events-------
    event deposit(address indexed _user, uint256 _amount, uint256 _timestamp); //Event: Deposited by user
    event Withdraw(address indexed _user, uint256 _amount, uint256 _timestamp); //Event: Withdraw by user
    event emergencyWithdrawRequestByOwner(
        address indexed owner,
        uint256 amount,
        uint256 _timestamp
    ); //Event: Withdrawn request applied by owner
    event emergencyWithdrawnByOwner(
        //Event: Withdrawn successfuly by OWNER
        address indexed owner,
        uint256 _amount,
        uint256 _timestamp
    ); //owner successfully withdrawn from emergency withdraw function
    event canceledEmergencyWithdraw(uint256 _amount, uint256 _timestamp);
    event withdrawEarlyEvent(
        address _user,
        uint256 _amountWithdrawn,
        uint256 _amountDeducted
    );
    //@owner
    // -------Set Owner--------
    address public immutable OWNER;
    // ---set timestamp for withdrawal delay for owner only---
    uint256 public timestampOwner = 0; //will save memory
    uint256 public ownerEmergencyWithdrawAmount;
    uint256 public penaltyFeeAccumulated = 0; //

    constructor() {
        OWNER = msg.sender; //whoever deploy will be owner of contract
    }

    modifier hasBalance() {
        if (depositors[msg.sender].balance == 0) revert NoDeposit();
        _;
    }

    //struct to store deposited balance details by user (timestamp, balance)
    struct DepositDetails {
        uint256 timestamp;
        uint256 balance;
    }

    //mapping from user to his deposited balance:
    mapping(address => DepositDetails) public depositors;

    //@function - deposit user balance (eth)

    function depositEth() external payable {
        if (msg.value < 0.1 ether)
            revert MinimumDeposit("Send at least 0.1 ether !"); //must deposit at least 0.1 eth

        DepositDetails memory depositDetails = depositors[msg.sender];
        uint256 newTotalBalance = depositDetails.balance + msg.value;

        //  Implementation to calculate new timestamp:
        // ((old balance * old timestamp stored in mapping) + (new balance * block.timestamp)) /(old balance+new Balance):
        uint256 weightedTimestamp = ((depositDetails.balance *
            depositDetails.timestamp) +
            (msg.value * (block.timestamp + 1 weeks))) / (newTotalBalance);

        //emit event:
        emit deposit(msg.sender, msg.value, block.timestamp);

        //set timestamp and balance of user...
        depositDetails = DepositDetails({
            balance: newTotalBalance,
            timestamp: weightedTimestamp
        });
        depositors[msg.sender] = depositDetails;
    }

    //@function - To withdraw user balance (eth)
    function withdrawUnlockedEth() external hasBalance {
        //GAS-OPTIMIZATION: Don't access state variable directly in function if there are multiple usages,
        //                   declare it in memory storage in function
        DepositDetails memory depositedBalance = depositors[msg.sender]; //GAS optimized

        if (block.timestamp < depositedBalance.timestamp) {
            revert TimeNotPassed(" 7 days not completed yet ! ");
        }

        uint256 withdrawnTime = depositedBalance.timestamp;
        uint256 amount = depositedBalance.balance;
        emit Withdraw(msg.sender, amount, withdrawnTime); // emit that amount withdrawn

        delete depositors[msg.sender]; // delete his deposited details
        (bool success, ) = payable(msg.sender).call{value: amount}(""); //send user funds
        if (!success) revert TransferFailed(); //revert call
    }

    //@function - Allows User withdrawn before 7 day lock => 20% amount deduction from his depsited amount
    function withdrawEarly() external hasBalance {
        uint256 userDeposit = depositors[msg.sender].balance;

        uint256 withdrawnAmmountAllowed = (userDeposit * 4) / 5; //~ amount to receive => 80%
        uint256 withdrawnAmmountDeducted = userDeposit -
            withdrawnAmmountAllowed; //~ amount to deduct => 20%

        emit withdrawEarlyEvent(
            msg.sender,
            withdrawnAmmountAllowed,
            withdrawnAmmountDeducted
        );

        // --- state changes ---
        delete depositors[msg.sender]; //delete the user record
        penaltyFeeAccumulated += withdrawnAmmountDeducted; //store the fees balance accumulated in feesBalance, to keep track of funds in contract

        (bool success, ) = payable(msg.sender).call{
            value: withdrawnAmmountAllowed
        }(""); //send user funds

        if (!success) revert TransferFailed();
    }

    //@function - Emergency withdraw by owner call, time delay will be 1 day for owner to withdraw ~ 86400 seconds
    function emergencyWithdraw() external {
        if (msg.sender != OWNER) revert NotOwner();

        if (timestampOwner == 0) {
            uint256 currentBalance = address(this).balance;

            timestampOwner = block.timestamp;
            ownerEmergencyWithdrawAmount = currentBalance;
            emit emergencyWithdrawRequestByOwner(
                OWNER,
                currentBalance,
                block.timestamp
            );
        } else {
            if (timestampOwner + 1 days > block.timestamp) {
                revert TimeNotPassed("Withdrawn time not reached");
            } //1 day should have passed from withdrawal request
            emit emergencyWithdrawnByOwner(
                OWNER,
                ownerEmergencyWithdrawAmount,
                block.timestamp
            ); // emit withdrawn by owner

            timestampOwner = 0;
            uint256 withdrawValue = ownerEmergencyWithdrawAmount;
            ownerEmergencyWithdrawAmount = 0;

            (bool success, ) = payable(OWNER).call{value: withdrawValue}(""); // sends the contract balance to owner
            if (!success) revert TransferFailed();
        }
    }

    //@owner - if owner wills to cancel its emergency withdraw request
    function cancelEmergencyWithdraw() external {
        if (msg.sender != OWNER) revert NotOwner();
        emit canceledEmergencyWithdraw(
            ownerEmergencyWithdrawAmount,
            block.timestamp
        );
        timestampOwner = 0;
        ownerEmergencyWithdrawAmount = 0;
    }

    function checkTimeStamp() external view returns (uint256) {
        return block.timestamp;
    }

    receive() external payable {}
}
