// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";

import {HookConfigLib} from "../../src/helpers/HookConfigLib.sol";
import {ModuleEntityLib} from "../../src/helpers/ModuleEntityLib.sol";
import {HookConfig, ModuleEntity} from "../../src/interfaces/IModuleManager.sol";

contract HookConfigLibTest is Test {
    using ModuleEntityLib for ModuleEntity;
    using HookConfigLib for HookConfig;

    // Tests the packing and unpacking of a hook config with a randomized state

    function testFuzz_hookConfig_packingUnderlying(
        address addr,
        uint32 entityId,
        bool isValidation,
        bool hasPre,
        bool hasPost
    ) public {
        HookConfig hookConfig;

        if (isValidation) {
            hookConfig = HookConfigLib.packValidationHook(addr, entityId);
        } else {
            hookConfig = HookConfigLib.packExecHook(addr, entityId, hasPre, hasPost);
        }

        assertEq(hookConfig.module(), addr, "module mismatch");
        assertEq(hookConfig.entityId(), entityId, "entityId mismatch");
        assertEq(hookConfig.isValidationHook(), isValidation, "isValidation mismatch");

        if (!isValidation) {
            assertEq(hookConfig.hasPreHook(), hasPre, "hasPre mismatch");
            assertEq(hookConfig.hasPostHook(), hasPost, "hasPost mismatch");
        }
    }

    function testFuzz_hookConfig_packingModuleEntity(
        ModuleEntity hookFunction,
        bool isValidation,
        bool hasPre,
        bool hasPost
    ) public {
        HookConfig hookConfig;

        if (isValidation) {
            hookConfig = HookConfigLib.packValidationHook(hookFunction);
        } else {
            hookConfig = HookConfigLib.packExecHook(hookFunction, hasPre, hasPost);
        }

        assertEq(
            ModuleEntity.unwrap(hookConfig.moduleEntity()),
            ModuleEntity.unwrap(hookFunction),
            "moduleEntity mismatch"
        );
        assertEq(hookConfig.isValidationHook(), isValidation, "isValidation mismatch");

        if (!isValidation) {
            assertEq(hookConfig.hasPreHook(), hasPre, "hasPre mismatch");
            assertEq(hookConfig.hasPostHook(), hasPost, "hasPost mismatch");
        }
    }
}
