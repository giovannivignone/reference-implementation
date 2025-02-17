// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {UpgradeableModularAccount} from "../../src/account/UpgradeableModularAccount.sol";

import {HookConfigLib} from "../../src/helpers/HookConfigLib.sol";
import {ModuleEntity} from "../../src/helpers/ModuleEntityLib.sol";

import {Counter} from "../mocks/Counter.sol";
import {MockAccessControlHookModule} from "../mocks/modules/MockAccessControlHookModule.sol";
import {CustomValidationTestBase} from "../utils/CustomValidationTestBase.sol";

contract PerHookDataTest is CustomValidationTestBase {
    using MessageHashUtils for bytes32;

    MockAccessControlHookModule internal _accessControlHookModule;

    Counter internal _counter;

    function setUp() public {
        _counter = new Counter();

        _accessControlHookModule = new MockAccessControlHookModule();

        _customValidationSetup();
    }

    function test_passAccessControl_userOp() public {
        assertEq(_counter.number(), 0);

        (PackedUserOperation memory userOp, bytes32 userOpHash) = _getCounterUserOP();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, userOpHash.toEthSignedMessageHash());

        PreValidationHookData[] memory preValidationHookData = new PreValidationHookData[](1);
        preValidationHookData[0] = PreValidationHookData({index: 0, validationData: abi.encodePacked(_counter)});

        userOp.signature = _encodeSignature(
            _signerValidation, GLOBAL_VALIDATION, preValidationHookData, abi.encodePacked(r, s, v)
        );

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        entryPoint.handleOps(userOps, beneficiary);

        assertEq(_counter.number(), 1);
    }

    function test_failAccessControl_badSigData_userOp() public {
        (PackedUserOperation memory userOp, bytes32 userOpHash) = _getCounterUserOP();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, userOpHash.toEthSignedMessageHash());

        PreValidationHookData[] memory preValidationHookData = new PreValidationHookData[](1);
        preValidationHookData[0] = PreValidationHookData({
            index: 0,
            validationData: abi.encodePacked(address(0x1234123412341234123412341234123412341234))
        });

        userOp.signature = _encodeSignature(
            _signerValidation, GLOBAL_VALIDATION, preValidationHookData, abi.encodePacked(r, s, v)
        );

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOpWithRevert.selector,
                0,
                "AA23 reverted",
                abi.encodeWithSignature("Error(string)", "Proof doesn't match target")
            )
        );
        entryPoint.handleOps(userOps, beneficiary);
    }

    function test_failAccessControl_noSigData_userOp() public {
        (PackedUserOperation memory userOp, bytes32 userOpHash) = _getCounterUserOP();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, userOpHash.toEthSignedMessageHash());

        userOp.signature = _encodeSignature(_signerValidation, GLOBAL_VALIDATION, abi.encodePacked(r, s, v));

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOpWithRevert.selector,
                0,
                "AA23 reverted",
                abi.encodeWithSignature("Error(string)", "Proof doesn't match target")
            )
        );
        entryPoint.handleOps(userOps, beneficiary);
    }

    function test_failAccessControl_badIndexProvided_userOp() public {
        (PackedUserOperation memory userOp, bytes32 userOpHash) = _getCounterUserOP();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, userOpHash.toEthSignedMessageHash());

        PreValidationHookData[] memory preValidationHookData = new PreValidationHookData[](2);
        preValidationHookData[0] = PreValidationHookData({index: 0, validationData: abi.encodePacked(_counter)});
        preValidationHookData[1] = PreValidationHookData({index: 1, validationData: abi.encodePacked(_counter)});

        userOp.signature = _encodeSignature(
            _signerValidation, GLOBAL_VALIDATION, preValidationHookData, abi.encodePacked(r, s, v)
        );

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOpWithRevert.selector,
                0,
                "AA23 reverted",
                abi.encodeWithSelector(UpgradeableModularAccount.ValidationSignatureSegmentMissing.selector)
            )
        );
        entryPoint.handleOps(userOps, beneficiary);
    }

    // todo: index out of order failure case with 2 pre hooks

    function test_failAccessControl_badTarget_userOp() public {
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(account1),
            nonce: 0,
            initCode: "",
            callData: abi.encodeCall(UpgradeableModularAccount.execute, (beneficiary, 1 wei, "")),
            accountGasLimits: _encodeGas(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: 0,
            gasFees: _encodeGas(1, 1),
            paymasterAndData: "",
            signature: ""
        });

        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, userOpHash.toEthSignedMessageHash());

        PreValidationHookData[] memory preValidationHookData = new PreValidationHookData[](1);
        preValidationHookData[0] = PreValidationHookData({index: 0, validationData: abi.encodePacked(beneficiary)});

        userOp.signature = _encodeSignature(
            _signerValidation, GLOBAL_VALIDATION, preValidationHookData, abi.encodePacked(r, s, v)
        );

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOpWithRevert.selector,
                0,
                "AA23 reverted",
                abi.encodeWithSignature("Error(string)", "Target not allowed")
            )
        );
        entryPoint.handleOps(userOps, beneficiary);
    }

    function test_failPerHookData_nonCanonicalEncoding_userOp() public {
        (PackedUserOperation memory userOp, bytes32 userOpHash) = _getCounterUserOP();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner1Key, userOpHash.toEthSignedMessageHash());

        PreValidationHookData[] memory preValidationHookData = new PreValidationHookData[](1);
        preValidationHookData[0] = PreValidationHookData({index: 0, validationData: ""});

        userOp.signature = _encodeSignature(
            _signerValidation, GLOBAL_VALIDATION, preValidationHookData, abi.encodePacked(r, s, v)
        );

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOpWithRevert.selector,
                0,
                "AA23 reverted",
                abi.encodeWithSelector(UpgradeableModularAccount.NonCanonicalEncoding.selector)
            )
        );
        entryPoint.handleOps(userOps, beneficiary);
    }

    function test_passAccessControl_runtime() public {
        assertEq(_counter.number(), 0);

        PreValidationHookData[] memory preValidationHookData = new PreValidationHookData[](1);
        preValidationHookData[0] = PreValidationHookData({index: 0, validationData: abi.encodePacked(_counter)});

        vm.prank(owner1);
        account1.executeWithAuthorization(
            abi.encodeCall(
                UpgradeableModularAccount.execute,
                (address(_counter), 0 wei, abi.encodeCall(Counter.increment, ()))
            ),
            _encodeSignature(_signerValidation, GLOBAL_VALIDATION, preValidationHookData, "")
        );

        assertEq(_counter.number(), 1);
    }

    function test_failAccessControl_badSigData_runtime() public {
        PreValidationHookData[] memory preValidationHookData = new PreValidationHookData[](1);
        preValidationHookData[0] = PreValidationHookData({
            index: 0,
            validationData: abi.encodePacked(address(0x1234123412341234123412341234123412341234))
        });

        vm.prank(owner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                UpgradeableModularAccount.PreRuntimeValidationHookFailed.selector,
                _accessControlHookModule,
                uint32(MockAccessControlHookModule.EntityId.PRE_VALIDATION_HOOK),
                abi.encodeWithSignature("Error(string)", "Proof doesn't match target")
            )
        );
        account1.executeWithAuthorization(
            abi.encodeCall(
                UpgradeableModularAccount.execute,
                (address(_counter), 0 wei, abi.encodeCall(Counter.increment, ()))
            ),
            _encodeSignature(_signerValidation, GLOBAL_VALIDATION, preValidationHookData, "")
        );
    }

    function test_failAccessControl_noSigData_runtime() public {
        vm.prank(owner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                UpgradeableModularAccount.PreRuntimeValidationHookFailed.selector,
                _accessControlHookModule,
                uint32(MockAccessControlHookModule.EntityId.PRE_VALIDATION_HOOK),
                abi.encodeWithSignature("Error(string)", "Proof doesn't match target")
            )
        );
        account1.executeWithAuthorization(
            abi.encodeCall(
                UpgradeableModularAccount.execute,
                (address(_counter), 0 wei, abi.encodeCall(Counter.increment, ()))
            ),
            _encodeSignature(_signerValidation, GLOBAL_VALIDATION, "")
        );
    }

    function test_failAccessControl_badIndexProvided_runtime() public {
        PreValidationHookData[] memory preValidationHookData = new PreValidationHookData[](2);
        preValidationHookData[0] = PreValidationHookData({index: 0, validationData: abi.encodePacked(_counter)});
        preValidationHookData[1] = PreValidationHookData({index: 1, validationData: abi.encodePacked(_counter)});

        vm.prank(owner1);
        vm.expectRevert(
            abi.encodeWithSelector(UpgradeableModularAccount.ValidationSignatureSegmentMissing.selector)
        );
        account1.executeWithAuthorization(
            abi.encodeCall(
                UpgradeableModularAccount.execute,
                (address(_counter), 0 wei, abi.encodeCall(Counter.increment, ()))
            ),
            _encodeSignature(_signerValidation, GLOBAL_VALIDATION, preValidationHookData, "")
        );
    }

    //todo: index out of order failure case with 2 pre hooks

    function test_failAccessControl_badTarget_runtime() public {
        PreValidationHookData[] memory preValidationHookData = new PreValidationHookData[](1);
        preValidationHookData[0] = PreValidationHookData({index: 0, validationData: abi.encodePacked(beneficiary)});

        vm.prank(owner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                UpgradeableModularAccount.PreRuntimeValidationHookFailed.selector,
                _accessControlHookModule,
                uint32(MockAccessControlHookModule.EntityId.PRE_VALIDATION_HOOK),
                abi.encodeWithSignature("Error(string)", "Target not allowed")
            )
        );
        account1.executeWithAuthorization(
            abi.encodeCall(UpgradeableModularAccount.execute, (beneficiary, 1 wei, "")),
            _encodeSignature(_signerValidation, GLOBAL_VALIDATION, preValidationHookData, "")
        );
    }

    function test_failPerHookData_nonCanonicalEncoding_runtime() public {
        PreValidationHookData[] memory preValidationHookData = new PreValidationHookData[](1);
        preValidationHookData[0] = PreValidationHookData({index: 0, validationData: ""});

        vm.prank(owner1);
        vm.expectRevert(abi.encodeWithSelector(UpgradeableModularAccount.NonCanonicalEncoding.selector));
        account1.executeWithAuthorization(
            abi.encodeCall(
                UpgradeableModularAccount.execute,
                (address(_counter), 0 wei, abi.encodeCall(Counter.increment, ()))
            ),
            _encodeSignature(_signerValidation, GLOBAL_VALIDATION, preValidationHookData, "")
        );
    }

    function _getCounterUserOP() internal view returns (PackedUserOperation memory, bytes32) {
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(account1),
            nonce: 0,
            initCode: "",
            callData: abi.encodeCall(
                UpgradeableModularAccount.execute, (address(_counter), 0 wei, abi.encodeCall(Counter.increment, ()))
            ),
            accountGasLimits: _encodeGas(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: 0,
            gasFees: _encodeGas(1, 1),
            paymasterAndData: "",
            signature: ""
        });

        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

        return (userOp, userOpHash);
    }

    // Test config

    function _initialValidationConfig()
        internal
        virtual
        override
        returns (ModuleEntity, bool, bool, bytes4[] memory, bytes memory, bytes[] memory)
    {
        bytes[] memory hooks = new bytes[](1);
        hooks[0] = abi.encodePacked(
            HookConfigLib.packValidationHook(
                address(_accessControlHookModule), uint32(MockAccessControlHookModule.EntityId.PRE_VALIDATION_HOOK)
            ),
            abi.encode(_counter)
        );

        return (
            _signerValidation,
            true,
            true,
            new bytes4[](0),
            abi.encode(TEST_DEFAULT_VALIDATION_ENTITY_ID, owner1),
            hooks
        );
    }
}
