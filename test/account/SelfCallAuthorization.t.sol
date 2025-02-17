// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IAccountExecute} from "@eth-infinitism/account-abstraction/interfaces/IAccountExecute.sol";
import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";

import {UpgradeableModularAccount} from "../../src/account/UpgradeableModularAccount.sol";

import {ModuleEntity, ModuleEntityLib} from "../../src/helpers/ModuleEntityLib.sol";
import {ValidationConfigLib} from "../../src/helpers/ValidationConfigLib.sol";
import {Call, IStandardExecutor} from "../../src/interfaces/IStandardExecutor.sol";

import {ComprehensiveModule} from "../mocks/modules/ComprehensiveModule.sol";
import {AccountTestBase} from "../utils/AccountTestBase.sol";

contract SelfCallAuthorizationTest is AccountTestBase {
    ComprehensiveModule public comprehensiveModule;

    ModuleEntity public comprehensiveModuleValidation;

    function setUp() public {
        // install the comprehensive module to get new exec functions with different validations configured.

        comprehensiveModule = new ComprehensiveModule();

        comprehensiveModuleValidation =
            ModuleEntityLib.pack(address(comprehensiveModule), uint32(ComprehensiveModule.EntityId.VALIDATION));

        bytes4[] memory validationSelectors = new bytes4[](1);
        validationSelectors[0] = ComprehensiveModule.foo.selector;

        vm.startPrank(address(entryPoint));
        account1.installExecution(address(comprehensiveModule), comprehensiveModule.executionManifest(), "");
        account1.installValidation(
            ValidationConfigLib.pack(comprehensiveModuleValidation, false, false),
            validationSelectors,
            "",
            new bytes[](0)
        );
        vm.stopPrank();
    }

    function test_selfCallFails_userOp() public {
        // Uses global validation
        _runUserOp(
            abi.encodeCall(ComprehensiveModule.foo, ()),
            abi.encodeWithSelector(
                IEntryPoint.FailedOpWithRevert.selector,
                0,
                "AA23 reverted",
                abi.encodeWithSelector(
                    UpgradeableModularAccount.ValidationFunctionMissing.selector, ComprehensiveModule.foo.selector
                )
            )
        );
    }

    function test_selfCallFails_execUserOp() public {
        // Uses global validation
        _runUserOp(
            abi.encodePacked(IAccountExecute.executeUserOp.selector, abi.encodeCall(ComprehensiveModule.foo, ())),
            abi.encodeWithSelector(
                IEntryPoint.FailedOpWithRevert.selector,
                0,
                "AA23 reverted",
                abi.encodeWithSelector(
                    UpgradeableModularAccount.ValidationFunctionMissing.selector, ComprehensiveModule.foo.selector
                )
            )
        );
    }

    function test_selfCallFails_runtime() public {
        // Uses global validation
        _runtimeCall(
            abi.encodeCall(ComprehensiveModule.foo, ()),
            abi.encodeWithSelector(
                UpgradeableModularAccount.ValidationFunctionMissing.selector, ComprehensiveModule.foo.selector
            )
        );
    }

    function test_selfCallPrivilegeEscalation_prevented_userOp() public {
        // Using global validation, self-call bypasses custom validation needed for ComprehensiveModule.foo
        _runUserOp(
            abi.encodeCall(
                UpgradeableModularAccount.execute,
                (address(account1), 0, abi.encodeCall(ComprehensiveModule.foo, ()))
            ),
            abi.encodeWithSelector(
                IEntryPoint.FailedOpWithRevert.selector,
                0,
                "AA23 reverted",
                abi.encodeWithSelector(UpgradeableModularAccount.SelfCallRecursionDepthExceeded.selector)
            )
        );

        Call[] memory calls = new Call[](1);
        calls[0] = Call(address(account1), 0, abi.encodeCall(ComprehensiveModule.foo, ()));

        _runUserOp(
            abi.encodeCall(IStandardExecutor.executeBatch, (calls)),
            abi.encodeWithSelector(
                IEntryPoint.FailedOpWithRevert.selector,
                0,
                "AA23 reverted",
                abi.encodeWithSelector(
                    UpgradeableModularAccount.ValidationFunctionMissing.selector, ComprehensiveModule.foo.selector
                )
            )
        );
    }

    function test_selfCallPrivilegeEscalation_prevented_execUserOp() public {
        // Using global validation, self-call bypasses custom validation needed for ComprehensiveModule.foo
        _runUserOp(
            abi.encodePacked(
                IAccountExecute.executeUserOp.selector,
                abi.encodeCall(
                    UpgradeableModularAccount.execute,
                    (address(account1), 0, abi.encodeCall(ComprehensiveModule.foo, ()))
                )
            ),
            abi.encodeWithSelector(
                IEntryPoint.FailedOpWithRevert.selector,
                0,
                "AA23 reverted",
                abi.encodeWithSelector(UpgradeableModularAccount.SelfCallRecursionDepthExceeded.selector)
            )
        );

        Call[] memory calls = new Call[](1);
        calls[0] = Call(address(account1), 0, abi.encodeCall(ComprehensiveModule.foo, ()));

        _runUserOp(
            abi.encodePacked(
                IAccountExecute.executeUserOp.selector, abi.encodeCall(IStandardExecutor.executeBatch, (calls))
            ),
            abi.encodeWithSelector(
                IEntryPoint.FailedOpWithRevert.selector,
                0,
                "AA23 reverted",
                abi.encodeWithSelector(
                    UpgradeableModularAccount.ValidationFunctionMissing.selector, ComprehensiveModule.foo.selector
                )
            )
        );
    }

    function test_selfCallPrivilegeEscalation_prevented_runtime() public {
        // Using global validation, self-call bypasses custom validation needed for ComprehensiveModule.foo
        _runtimeCall(
            abi.encodeCall(
                UpgradeableModularAccount.execute,
                (address(account1), 0, abi.encodeCall(ComprehensiveModule.foo, ()))
            ),
            abi.encodeWithSelector(UpgradeableModularAccount.SelfCallRecursionDepthExceeded.selector)
        );

        Call[] memory calls = new Call[](1);
        calls[0] = Call(address(account1), 0, abi.encodeCall(ComprehensiveModule.foo, ()));

        _runtimeExecBatchExpFail(
            calls,
            abi.encodeWithSelector(
                UpgradeableModularAccount.ValidationFunctionMissing.selector, ComprehensiveModule.foo.selector
            )
        );
    }

    function test_batchAction_allowed_userOp() public {
        _enableBatchValidation();

        Call[] memory calls = new Call[](2);
        calls[0] = Call(address(account1), 0, abi.encodeCall(ComprehensiveModule.foo, ()));
        calls[1] = Call(address(account1), 0, abi.encodeCall(ComprehensiveModule.foo, ()));

        PackedUserOperation memory userOp = _generateUserOpWithComprehensiveModuleValidation(
            abi.encodeCall(IStandardExecutor.executeBatch, (calls))
        );

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        vm.expectCall(address(comprehensiveModule), abi.encodeCall(ComprehensiveModule.foo, ()), 2);
        entryPoint.handleOps(userOps, beneficiary);
    }

    function test_batchAction_allowed_execUserOp() public {
        _enableBatchValidation();

        Call[] memory calls = new Call[](2);
        calls[0] = Call(address(account1), 0, abi.encodeCall(ComprehensiveModule.foo, ()));
        calls[1] = Call(address(account1), 0, abi.encodeCall(ComprehensiveModule.foo, ()));

        PackedUserOperation memory userOp = _generateUserOpWithComprehensiveModuleValidation(
            abi.encodePacked(
                IAccountExecute.executeUserOp.selector, abi.encodeCall(IStandardExecutor.executeBatch, (calls))
            )
        );

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        vm.expectCall(address(comprehensiveModule), abi.encodeCall(ComprehensiveModule.foo, ()), 2);
        entryPoint.handleOps(userOps, beneficiary);
    }

    function test_batchAction_allowed_runtime() public {
        _enableBatchValidation();

        Call[] memory calls = new Call[](2);
        calls[0] = Call(address(account1), 0, abi.encodeCall(ComprehensiveModule.foo, ()));
        calls[1] = Call(address(account1), 0, abi.encodeCall(ComprehensiveModule.foo, ()));

        vm.expectCall(address(comprehensiveModule), abi.encodeCall(ComprehensiveModule.foo, ()), 2);
        account1.executeWithAuthorization(
            abi.encodeCall(IStandardExecutor.executeBatch, (calls)),
            _encodeSignature(comprehensiveModuleValidation, SELECTOR_ASSOCIATED_VALIDATION, "")
        );
    }

    function test_recursiveDepthCapped_userOp() public {
        _enableBatchValidation();

        Call[] memory innerCalls = new Call[](1);
        innerCalls[0] = Call(address(account1), 0, abi.encodeCall(ComprehensiveModule.foo, ()));

        Call[] memory outerCalls = new Call[](1);
        outerCalls[0] = Call(address(account1), 0, abi.encodeCall(IStandardExecutor.executeBatch, (innerCalls)));

        PackedUserOperation memory userOp = _generateUserOpWithComprehensiveModuleValidation(
            abi.encodeCall(IStandardExecutor.executeBatch, (outerCalls))
        );

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOpWithRevert.selector,
                0,
                "AA23 reverted",
                abi.encodeWithSelector(UpgradeableModularAccount.SelfCallRecursionDepthExceeded.selector)
            )
        );
        entryPoint.handleOps(userOps, beneficiary);
    }

    function test_recursiveDepthCapped_execUserOp() public {
        _enableBatchValidation();

        Call[] memory innerCalls = new Call[](1);
        innerCalls[0] = Call(address(account1), 0, abi.encodeCall(ComprehensiveModule.foo, ()));

        Call[] memory outerCalls = new Call[](1);
        outerCalls[0] = Call(address(account1), 0, abi.encodeCall(IStandardExecutor.executeBatch, (innerCalls)));

        PackedUserOperation memory userOp = _generateUserOpWithComprehensiveModuleValidation(
            abi.encodePacked(
                IAccountExecute.executeUserOp.selector,
                abi.encodeCall(IStandardExecutor.executeBatch, (outerCalls))
            )
        );

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOpWithRevert.selector,
                0,
                "AA23 reverted",
                abi.encodeWithSelector(UpgradeableModularAccount.SelfCallRecursionDepthExceeded.selector)
            )
        );
        entryPoint.handleOps(userOps, beneficiary);
    }

    function test_recursiveDepthCapped_runtime() public {
        _enableBatchValidation();

        Call[] memory innerCalls = new Call[](1);
        innerCalls[0] = Call(address(account1), 0, abi.encodeCall(ComprehensiveModule.foo, ()));

        Call[] memory outerCalls = new Call[](1);
        outerCalls[0] = Call(address(account1), 0, abi.encodeCall(IStandardExecutor.executeBatch, (innerCalls)));

        vm.expectRevert(abi.encodeWithSelector(UpgradeableModularAccount.SelfCallRecursionDepthExceeded.selector));
        account1.executeWithAuthorization(
            abi.encodeCall(IStandardExecutor.executeBatch, (outerCalls)),
            _encodeSignature(comprehensiveModuleValidation, SELECTOR_ASSOCIATED_VALIDATION, "")
        );
    }

    function _enableBatchValidation() internal {
        // Extend ComprehensiveModule's validation function to also validate `executeBatch`, to allow the
        // self-call.

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IStandardExecutor.executeBatch.selector;

        vm.prank(owner1);
        account1.executeWithAuthorization(
            abi.encodeCall(
                UpgradeableModularAccount.installValidation,
                (
                    ValidationConfigLib.pack(comprehensiveModuleValidation, false, false),
                    selectors,
                    "",
                    new bytes[](0)
                )
            ),
            _encodeSignature(_signerValidation, GLOBAL_VALIDATION, "")
        );
    }

    function _generateUserOpWithComprehensiveModuleValidation(bytes memory callData)
        internal
        view
        returns (PackedUserOperation memory)
    {
        uint256 nonce = entryPoint.getNonce(address(account1), 0);
        return PackedUserOperation({
            sender: address(account1),
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: _encodeGas(VERIFICATION_GAS_LIMIT, CALL_GAS_LIMIT),
            preVerificationGas: 0,
            gasFees: _encodeGas(1, 1),
            paymasterAndData: hex"",
            signature: _encodeSignature(
                comprehensiveModuleValidation,
                SELECTOR_ASSOCIATED_VALIDATION,
                // Comprehensive module's validation function doesn't actually check anything, so we don't need to
                // sign anything.
                ""
            )
        });
    }
}
