// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.7.6;
pragma abicoder v2;

import 'forge-std/Test.sol';
import '../src/LiquidManager.sol';
import '../lib/v3-core/contracts/libraries/TickMath.sol';
import '../src/KeeperRegistrar2_0Interface.sol';

contract LiquidManagerTest is Test {


    address USER = makeAddr("user");
    uint256 constant STARTING_BALANCE = 10 ether;

    // KeeperRegistrar2_0Interface.RegistrationParams
    //          params = KeeperRegistrar2_0Interface.RegistrationParams({
    //             name: string('hjbhbj'),
    //             encryptedEmail: abi.encode("0x"),
    //             upkeepContract: address(this),
    //             gasLimit: 500000,
    //             adminAddress: 0x3B66e7a2C8147EA2f5FCf39613492774F361A0DF,
    //             checkData: abi.encode("0x"),
    //             offchainConfig: abi.encode("0x"),
    //             amount: 100000000000000000
    //         });

    function testMint() public {
   
        LiquidManager(0x29d3B740e43a4a0E6e1f8d3A2B79Aa98111b7832)._checkPositionForClosure(213431, 0x326C977E6efc84E512bB9C30f76E30c160eD06FB, 0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889, 500);
    }
        // jobRegistration(params);
        // job(6791, 0x779877A7B0D9E8603169DdbD7836e478b4624789, 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14, 3000);
    
}