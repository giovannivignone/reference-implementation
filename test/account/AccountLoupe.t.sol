// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import {HookConfigLib} from "../../src/helpers/HookConfigLib.sol";
import {ModuleEntity, ModuleEntityLib} from "../../src/helpers/ModuleEntityLib.sol";
import {ExecutionHook} from "../../src/interfaces/IAccountLoupe.sol";
import {IModuleManager} from "../../src/interfaces/IModuleManager.sol";
import {IStandardExecutor} from "../../src/interfaces/IStandardExecutor.sol";

import {ComprehensiveModule} from "../mocks/modules/ComprehensiveModule.sol";
import {CustomValidationTestBase} from "../utils/CustomValidationTestBase.sol";

contract AccountLoupeTest is CustomValidationTestBase {
    ComprehensiveModule public comprehensiveModule;

    event ReceivedCall(bytes msgData, uint256 msgValue);

    ModuleEntity public comprehensiveModuleValidation;

    function setUp() public {
        comprehensiveModule = new ComprehensiveModule();
        comprehensiveModuleValidation =
            ModuleEntityLib.pack(address(comprehensiveModule), uint32(ComprehensiveModule.EntityId.VALIDATION));

        _customValidationSetup();

        vm.startPrank(address(entryPoint));
        account1.installExecution(address(comprehensiveModule), comprehensiveModule.executionManifest(), "");
        vm.stopPrank();
    }

    function test_moduleLoupe_getExecutionFunctionHandler_native() public {
        bytes4[] memory selectorsToCheck = new bytes4[](5);

        selectorsToCheck[0] = IStandardExecutor.execute.selector;

        selectorsToCheck[1] = IStandardExecutor.executeBatch.selector;

        selectorsToCheck[2] = UUPSUpgradeable.upgradeToAndCall.selector;

        selectorsToCheck[3] = IModuleManager.installExecution.selector;

        selectorsToCheck[4] = IModuleManager.uninstallExecution.selector;

        for (uint256 i = 0; i < selectorsToCheck.length; i++) {
            address module = account1.getExecutionFunctionHandler(selectorsToCheck[i]);

            assertEq(module, address(account1));
        }
    }

    function test_moduleLoupe_getExecutionFunctionConfig_module() public {
        bytes4[] memory selectorsToCheck = new bytes4[](1);
        address[] memory expectedModuleAddress = new address[](1);

        selectorsToCheck[0] = comprehensiveModule.foo.selector;
        expectedModuleAddress[0] = address(comprehensiveModule);

        for (uint256 i = 0; i < selectorsToCheck.length; i++) {
            address module = account1.getExecutionFunctionHandler(selectorsToCheck[i]);

            assertEq(module, expectedModuleAddress[i]);
        }
    }

    function test_moduleLoupe_getSelectors() public {
        bytes4[] memory selectors = account1.getSelectors(comprehensiveModuleValidation);

        assertEq(selectors.length, 1);
        assertEq(selectors[0], comprehensiveModule.foo.selector);
    }

    function test_moduleLoupe_getExecutionHooks() public {
        ExecutionHook[] memory hooks = account1.getExecutionHooks(comprehensiveModule.foo.selector);
        ExecutionHook[3] memory expectedHooks = [
            ExecutionHook({
                hookFunction: ModuleEntityLib.pack(
                    address(comprehensiveModule), uint32(ComprehensiveModule.EntityId.BOTH_EXECUTION_HOOKS)
                ),
                isPreHook: true,
                isPostHook: true
            }),
            ExecutionHook({
                hookFunction: ModuleEntityLib.pack(
                    address(comprehensiveModule), uint32(ComprehensiveModule.EntityId.PRE_EXECUTION_HOOK)
                ),
                isPreHook: true,
                isPostHook: false
            }),
            ExecutionHook({
                hookFunction: ModuleEntityLib.pack(
                    address(comprehensiveModule), uint32(ComprehensiveModule.EntityId.POST_EXECUTION_HOOK)
                ),
                isPreHook: false,
                isPostHook: true
            })
        ];

        assertEq(hooks.length, 3);
        for (uint256 i = 0; i < hooks.length; i++) {
            assertEq(
                ModuleEntity.unwrap(hooks[i].hookFunction), ModuleEntity.unwrap(expectedHooks[i].hookFunction)
            );
            assertEq(hooks[i].isPreHook, expectedHooks[i].isPreHook);
            assertEq(hooks[i].isPostHook, expectedHooks[i].isPostHook);
        }
    }

    function test_moduleLoupe_getValidationHooks() public {
        ModuleEntity[] memory hooks = account1.getPreValidationHooks(comprehensiveModuleValidation);

        assertEq(hooks.length, 2);
        assertEq(
            ModuleEntity.unwrap(hooks[0]),
            ModuleEntity.unwrap(
                ModuleEntityLib.pack(
                    address(comprehensiveModule), uint32(ComprehensiveModule.EntityId.PRE_VALIDATION_HOOK_1)
                )
            )
        );
        assertEq(
            ModuleEntity.unwrap(hooks[1]),
            ModuleEntity.unwrap(
                ModuleEntityLib.pack(
                    address(comprehensiveModule), uint32(ComprehensiveModule.EntityId.PRE_VALIDATION_HOOK_2)
                )
            )
        );
    }

    // Test config

    function _initialValidationConfig()
        internal
        virtual
        override
        returns (ModuleEntity, bool, bool, bytes4[] memory, bytes memory, bytes[] memory)
    {
        bytes[] memory hooks = new bytes[](2);
        hooks[0] = abi.encodePacked(
            HookConfigLib.packValidationHook(
                address(comprehensiveModule), uint32(ComprehensiveModule.EntityId.PRE_VALIDATION_HOOK_1)
            )
        );
        hooks[1] = abi.encodePacked(
            HookConfigLib.packValidationHook(
                address(comprehensiveModule), uint32(ComprehensiveModule.EntityId.PRE_VALIDATION_HOOK_2)
            )
        );

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = comprehensiveModule.foo.selector;

        return (comprehensiveModuleValidation, true, true, selectors, bytes(""), hooks);
    }
}
