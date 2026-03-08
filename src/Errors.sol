//SPDX-License-Identifier:MIT
pragma solidity ^0.8.28;

error MinimumDeposit(string _reason); //If user have not deposited minimum required amount
error TimeNotPassed(string _reason); //If time has not been passed
error TransferFailed(); //If sending value failed
error NotOwner(); //If not owner
error NoDeposit(); //If not owner
