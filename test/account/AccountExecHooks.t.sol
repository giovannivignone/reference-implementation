// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {
    ExecutionManifest,
    IModule,
    ManifestExecutionFunction,
    ManifestExecutionHook
} from "../../src/interfaces/IExecution.sol";
import {IExecutionHook} from "../../src/interfaces/IExecutionHook.sol";

import {MockModule} from "../mocks/MockModule.sol";
import {AccountTestBase} from "../utils/AccountTestBase.sol";

contract AccountExecHooksTest is AccountTestBase {
    MockModule public mockModule1;

    bytes4 internal constant _EXEC_SELECTOR = bytes4(uint32(1));
    uint32 internal constant _PRE_HOOK_FUNCTION_ID_1 = 1;
    uint32 internal constant _POST_HOOK_FUNCTION_ID_2 = 2;
    uint32 internal constant _BOTH_HOOKS_FUNCTION_ID_3 = 3;

    ExecutionManifest internal _m1;

    event ModuleInstalled(address indexed module);
    event ModuleUninstalled(address indexed module, bool indexed callbacksSucceeded);
    // emitted by MockModule
    event ReceivedCall(bytes msgData, uint256 msgValue);

    function setUp() public {
        _transferOwnershipToTest();

        _m1.executionFunctions.push(
            ManifestExecutionFunction({
                executionSelector: _EXEC_SELECTOR,
                isPublic: true,
                allowGlobalValidation: false
            })
        );
    }

    function test_preExecHook_install() public {
        _installExecution1WithHooks(
            ManifestExecutionHook({
                executionSelector: _EXEC_SELECTOR,
                entityId: _PRE_HOOK_FUNCTION_ID_1,
                isPreHook: true,
                isPostHook: false
            })
        );
    }

    /// @dev Module 1 hook pair: [1, null]
    ///      Expected execution: [1, null]
    function test_preExecHook_run() public {
        test_preExecHook_install();

        vm.expectEmit(true, true, true, true);
        emit ReceivedCall(
            abi.encodeWithSelector(
                IExecutionHook.preExecutionHook.selector,
                _PRE_HOOK_FUNCTION_ID_1,
                address(this), // caller
                uint256(0), // msg.value in call to account
                abi.encodeWithSelector(_EXEC_SELECTOR)
            ),
            0 // msg value in call to module
        );

        (bool success,) = address(account1).call(abi.encodeWithSelector(_EXEC_SELECTOR));
        assertTrue(success);
    }

    function test_preExecHook_uninstall() public {
        test_preExecHook_install();

        _uninstallExecution(mockModule1);
    }

    function test_execHookPair_install() public {
        _installExecution1WithHooks(
            ManifestExecutionHook({
                executionSelector: _EXEC_SELECTOR,
                entityId: _BOTH_HOOKS_FUNCTION_ID_3,
                isPreHook: true,
                isPostHook: true
            })
        );
    }

    /// @dev Module 1 hook pair: [1, 2]
    ///      Expected execution: [1, 2]
    function test_execHookPair_run() public {
        test_execHookPair_install();

        vm.expectEmit(true, true, true, true);
        // pre hook call
        emit ReceivedCall(
            abi.encodeWithSelector(
                IExecutionHook.preExecutionHook.selector,
                _BOTH_HOOKS_FUNCTION_ID_3,
                address(this), // caller
                uint256(0), // msg.value in call to account
                abi.encodeWithSelector(_EXEC_SELECTOR)
            ),
            0 // msg value in call to module
        );
        vm.expectEmit(true, true, true, true);
        // exec call
        emit ReceivedCall(abi.encodePacked(_EXEC_SELECTOR), 0);
        vm.expectEmit(true, true, true, true);
        // post hook call
        emit ReceivedCall(
            abi.encodeCall(IExecutionHook.postExecutionHook, (_BOTH_HOOKS_FUNCTION_ID_3, "")),
            0 // msg value in call to module
        );

        (bool success,) = address(account1).call(abi.encodeWithSelector(_EXEC_SELECTOR));
        assertTrue(success);
    }

    function test_execHookPair_uninstall() public {
        test_execHookPair_install();

        _uninstallExecution(mockModule1);
    }

    function test_postOnlyExecHook_install() public {
        _installExecution1WithHooks(
            ManifestExecutionHook({
                executionSelector: _EXEC_SELECTOR,
                entityId: _POST_HOOK_FUNCTION_ID_2,
                isPreHook: false,
                isPostHook: true
            })
        );
    }

    /// @dev Module 1 hook pair: [null, 2]
    ///      Expected execution: [null, 2]
    function test_postOnlyExecHook_run() public {
        test_postOnlyExecHook_install();

        vm.expectEmit(true, true, true, true);
        emit ReceivedCall(
            abi.encodeCall(IExecutionHook.postExecutionHook, (_POST_HOOK_FUNCTION_ID_2, "")),
            0 // msg value in call to module
        );

        (bool success,) = address(account1).call(abi.encodeWithSelector(_EXEC_SELECTOR));
        assertTrue(success);
    }

    function test_postOnlyExecHook_uninstall() public {
        test_postOnlyExecHook_install();

        _uninstallExecution(mockModule1);
    }

    function _installExecution1WithHooks(ManifestExecutionHook memory execHooks) internal {
        _m1.executionHooks.push(execHooks);
        mockModule1 = new MockModule(_m1);

        vm.expectEmit(true, true, true, true);
        emit ReceivedCall(abi.encodeCall(IModule.onInstall, (bytes(""))), 0);
        vm.expectEmit(true, true, true, true);
        emit ModuleInstalled(address(mockModule1));

        vm.startPrank(address(entryPoint));
        account1.installExecution({
            module: address(mockModule1),
            manifest: mockModule1.executionManifest(),
            moduleInstallData: bytes("")
        });
        vm.stopPrank();
    }

    function _uninstallExecution(MockModule module) internal {
        vm.expectEmit(true, true, true, true);
        emit ReceivedCall(abi.encodeCall(IModule.onUninstall, (bytes(""))), 0);
        vm.expectEmit(true, true, true, true);
        emit ModuleUninstalled(address(module), true);

        vm.startPrank(address(entryPoint));
        account1.uninstallExecution(address(module), module.executionManifest(), bytes(""));
        vm.stopPrank();
    }
}
