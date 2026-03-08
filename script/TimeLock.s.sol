// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {TimeLock} from "../src/TimeLock.sol";

contract script is Script {
    //deploy the contract
    function run() public {
        vm.startBroadcast();
        new TimeLock();
        vm.stopBroadcast();
    }
}
