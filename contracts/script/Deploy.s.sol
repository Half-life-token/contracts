// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {HalfLife} from "../src/HalfLifeToken.sol";

contract Deploy is Script {
    HalfLife hl;

    function run() public {
        vm.startBroadcast();
        hl = new HalfLife(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        vm.stopBroadcast();
    }
}