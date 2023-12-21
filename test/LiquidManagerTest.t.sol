// // SPDX-License-Identifier: GPL-2.0-or-later
// pragma solidity ^0.7.6;
// pragma abicoder v2;

// import 'forge-std/Test.sol';
// import '../src/LiquidManager.sol';
// import '../lib/v3-core/contracts/libraries/TickMath.sol';
// import '../src/KeeperRegistrar2_0Interface.sol';

// contract LiquidManagerTest is Test {


//     address USER = makeAddr("user");
//     uint256 constant STARTING_BALANCE = 10 ether;

//     // KeeperRegistrar2_0Interface.RegistrationParams
//     //          params = KeeperRegistrar2_0Interface.RegistrationParams({
//     //             name: string('hjbhbj'),
//     //             encryptedEmail: abi.encode("0x"),
//     //             upkeepContract: address(this),
//     //             gasLimit: 500000,
//     //             adminAddress: 0x3B66e7a2C8147EA2f5FCf39613492774F361A0DF,
//     //             checkData: abi.encode("0x"),
//     //             offchainConfig: abi.encode("0x"),
//     //             amount: 100000000000000000
//     //         });

//     function testMint() public {
//         vm.deal(address(this), STARTING_BALANCE);
//         LiquidManager(0x09BBfE938852D2AC925F7C2E514bE1564B4A7430).job(6820, 0x779877A7B0D9E8603169DdbD7836e478b4624789, 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14, 3000);
//     }
//         // jobRegistration(params);
//         // job(6791, 0x779877A7B0D9E8603169DdbD7836e478b4624789, 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14, 3000);
    
// }