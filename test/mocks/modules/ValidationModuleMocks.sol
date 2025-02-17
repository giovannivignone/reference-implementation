// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";

import {ExecutionManifest, IExecution, ManifestExecutionFunction} from "../../../src/interfaces/IExecution.sol";
import {ModuleMetadata} from "../../../src/interfaces/IModule.sol";
import {IValidation} from "../../../src/interfaces/IValidation.sol";
import {IValidationHook} from "../../../src/interfaces/IValidationHook.sol";
import {BaseModule} from "../../../src/modules/BaseModule.sol";

abstract contract MockBaseUserOpValidationModule is IExecution, IValidation, IValidationHook, BaseModule {
    enum EntityId {
        USER_OP_VALIDATION,
        PRE_VALIDATION_HOOK_1,
        PRE_VALIDATION_HOOK_2
    }

    uint256 internal _userOpValidationFunctionData;
    uint256 internal _preUserOpValidationHook1Data;
    uint256 internal _preUserOpValidationHook2Data;

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Module interface functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function onInstall(bytes calldata) external override {}

    function onUninstall(bytes calldata) external override {}

    function preUserOpValidationHook(uint32 entityId, PackedUserOperation calldata, bytes32)
        external
        view
        override
        returns (uint256)
    {
        if (entityId == uint32(EntityId.PRE_VALIDATION_HOOK_1)) {
            return _preUserOpValidationHook1Data;
        } else if (entityId == uint32(EntityId.PRE_VALIDATION_HOOK_2)) {
            return _preUserOpValidationHook2Data;
        }
        revert NotImplemented();
    }

    function validateUserOp(uint32 entityId, PackedUserOperation calldata, bytes32)
        external
        view
        override
        returns (uint256)
    {
        if (entityId == uint32(EntityId.USER_OP_VALIDATION)) {
            return _userOpValidationFunctionData;
        }
        revert NotImplemented();
    }

    function validateSignature(address, uint32, address, bytes32, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        revert NotImplemented();
    }

    // Empty stubs
    function moduleMetadata() external pure override returns (ModuleMetadata memory) {}

    function preRuntimeValidationHook(uint32, address, uint256, bytes calldata, bytes calldata)
        external
        pure
        override
    {
        revert NotImplemented();
    }

    function validateRuntime(address, uint32, address, uint256, bytes calldata, bytes calldata)
        external
        pure
        override
    {
        revert NotImplemented();
    }
}

contract MockUserOpValidationModule is MockBaseUserOpValidationModule {
    function setValidationData(uint256 userOpValidationFunctionData) external {
        _userOpValidationFunctionData = userOpValidationFunctionData;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function foo() external {}

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Module interface functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function executionManifest() external pure override returns (ExecutionManifest memory) {
        ExecutionManifest memory manifest;

        manifest.executionFunctions = new ManifestExecutionFunction[](1);
        manifest.executionFunctions[0] = ManifestExecutionFunction({
            executionSelector: this.foo.selector,
            isPublic: false,
            allowGlobalValidation: false
        });

        return manifest;
    }
}

contract MockUserOpValidation1HookModule is MockBaseUserOpValidationModule {
    function setValidationData(uint256 userOpValidationFunctionData, uint256 preUserOpValidationHook1Data)
        external
    {
        _userOpValidationFunctionData = userOpValidationFunctionData;
        _preUserOpValidationHook1Data = preUserOpValidationHook1Data;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function bar() external {}

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Module interface functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function executionManifest() external pure override returns (ExecutionManifest memory) {
        ExecutionManifest memory manifest;

        manifest.executionFunctions = new ManifestExecutionFunction[](1);
        manifest.executionFunctions[0] = ManifestExecutionFunction({
            executionSelector: this.bar.selector,
            isPublic: false,
            allowGlobalValidation: false
        });

        return manifest;
    }
}

contract MockUserOpValidation2HookModule is MockBaseUserOpValidationModule {
    function setValidationData(
        uint256 userOpValidationFunctionData,
        uint256 preUserOpValidationHook1Data,
        uint256 preUserOpValidationHook2Data
    ) external {
        _userOpValidationFunctionData = userOpValidationFunctionData;
        _preUserOpValidationHook1Data = preUserOpValidationHook1Data;
        _preUserOpValidationHook2Data = preUserOpValidationHook2Data;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function baz() external {}

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Module interface functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function executionManifest() external pure override returns (ExecutionManifest memory) {
        ExecutionManifest memory manifest;

        manifest.executionFunctions = new ManifestExecutionFunction[](1);
        manifest.executionFunctions[0] = ManifestExecutionFunction({
            executionSelector: this.baz.selector,
            isPublic: false,
            allowGlobalValidation: false
        });

        return manifest;
    }
}
