// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {HookConfig, ModuleEntity} from "../interfaces/IModuleManager.sol";

// Hook types:
// Exec hook: bools for hasPre, hasPost
// Validation hook: no bools

// Hook fields:
// module address
// entity ID
// hook type
// if exec hook: hasPre, hasPost

// Hook config is a packed representation of a hook function and flags for its configuration.
// Layout:
// 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA________________________ // Address
// 0x________________________________________BBBBBBBB________________ // Entity ID
// 0x________________________________________________CC______________ // Type
// 0x__________________________________________________DD____________ // exec hook flags
//

// Hook types:
// 0x00 // Exec (selector and validation associated)
// 0x01 // Validation

// Exec hook flags layout:
// 0b000000__ // unused
// 0b______A_ // hasPre
// 0b_______B // hasPost

library HookConfigLib {
    // Hook type constants
    // Exec has no bits set
    bytes32 internal constant _HOOK_TYPE_EXEC = bytes32(uint256(0));
    // Validation has 1 in the 25th byte
    bytes32 internal constant _HOOK_TYPE_VALIDATION = bytes32(uint256(1) << 56);

    // Exec hook flags constants
    // Pre hook has 1 in 2's bit in the 26th byte
    bytes32 internal constant _EXEC_HOOK_HAS_PRE = bytes32(uint256(1) << 49);
    // Post hook has 1 in 1's bit in the 26th byte
    bytes32 internal constant _EXEC_HOOK_HAS_POST = bytes32(uint256(1) << 48);

    function packValidationHook(ModuleEntity _hookFunction) internal pure returns (HookConfig) {
        return
            HookConfig.wrap(bytes26(bytes26(ModuleEntity.unwrap(_hookFunction)) | bytes26(_HOOK_TYPE_VALIDATION)));
    }

    function packValidationHook(address _module, uint32 _entityId) internal pure returns (HookConfig) {
        return HookConfig.wrap(
            bytes25(
                // module address stored in the first 20 bytes
                bytes25(bytes20(_module))
                // entityId stored in the 21st - 24th byte
                | bytes25(bytes24(uint192(_entityId))) | bytes25(_HOOK_TYPE_VALIDATION)
            )
        );
    }

    function packExecHook(ModuleEntity _hookFunction, bool _hasPre, bool _hasPost)
        internal
        pure
        returns (HookConfig)
    {
        return HookConfig.wrap(
            bytes26(
                bytes26(ModuleEntity.unwrap(_hookFunction))
                // | bytes26(_HOOK_TYPE_EXEC) // Can omit because exec type is 0
                | bytes26(_hasPre ? _EXEC_HOOK_HAS_PRE : bytes32(0))
                    | bytes26(_hasPost ? _EXEC_HOOK_HAS_POST : bytes32(0))
            )
        );
    }

    function packExecHook(address _module, uint32 _entityId, bool _hasPre, bool _hasPost)
        internal
        pure
        returns (HookConfig)
    {
        return HookConfig.wrap(
            bytes26(
                // module address stored in the first 20 bytes
                bytes26(bytes20(_module))
                // entityId stored in the 21st - 24th byte
                | bytes26(bytes24(uint192(_entityId)))
                // | bytes26(_HOOK_TYPE_EXEC) // Can omit because exec type is 0
                | bytes26(_hasPre ? _EXEC_HOOK_HAS_PRE : bytes32(0))
                    | bytes26(_hasPost ? _EXEC_HOOK_HAS_POST : bytes32(0))
            )
        );
    }

    function unpackValidationHook(HookConfig _config) internal pure returns (ModuleEntity _hookFunction) {
        bytes26 configBytes = HookConfig.unwrap(_config);
        _hookFunction = ModuleEntity.wrap(bytes24(configBytes));
    }

    function unpackExecHook(HookConfig _config)
        internal
        pure
        returns (ModuleEntity _hookFunction, bool _hasPre, bool _hasPost)
    {
        bytes26 configBytes = HookConfig.unwrap(_config);
        _hookFunction = ModuleEntity.wrap(bytes24(configBytes));
        _hasPre = configBytes & _EXEC_HOOK_HAS_PRE != 0;
        _hasPost = configBytes & _EXEC_HOOK_HAS_POST != 0;
    }

    function module(HookConfig _config) internal pure returns (address) {
        return address(bytes20(HookConfig.unwrap(_config)));
    }

    function entityId(HookConfig _config) internal pure returns (uint32) {
        return uint32(bytes4(HookConfig.unwrap(_config) << 160));
    }

    function moduleEntity(HookConfig _config) internal pure returns (ModuleEntity) {
        return ModuleEntity.wrap(bytes24(HookConfig.unwrap(_config)));
    }

    // Check if the hook is a validation hook
    // If false, it is an exec hook
    function isValidationHook(HookConfig _config) internal pure returns (bool) {
        return HookConfig.unwrap(_config) & _HOOK_TYPE_VALIDATION != 0;
    }

    // Check if the exec hook has a pre hook
    // Undefined behavior if the hook is not an exec hook
    function hasPreHook(HookConfig _config) internal pure returns (bool) {
        return HookConfig.unwrap(_config) & _EXEC_HOOK_HAS_PRE != 0;
    }

    // Check if the exec hook has a post hook
    // Undefined behavior if the hook is not an exec hook
    function hasPostHook(HookConfig _config) internal pure returns (bool) {
        return HookConfig.unwrap(_config) & _EXEC_HOOK_HAS_POST != 0;
    }
}
