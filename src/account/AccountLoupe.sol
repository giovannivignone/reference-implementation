// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {HookConfigLib} from "../helpers/HookConfigLib.sol";
import {ExecutionHook, IAccountLoupe} from "../interfaces/IAccountLoupe.sol";
import {HookConfig, IModuleManager, ModuleEntity} from "../interfaces/IModuleManager.sol";
import {IStandardExecutor} from "../interfaces/IStandardExecutor.sol";
import {getAccountStorage, toHookConfig, toSelector} from "./AccountStorage.sol";

abstract contract AccountLoupe is IAccountLoupe {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using HookConfigLib for HookConfig;

    /// @inheritdoc IAccountLoupe
    function getExecutionFunctionHandler(bytes4 selector) external view override returns (address module) {
        if (
            selector == IStandardExecutor.execute.selector || selector == IStandardExecutor.executeBatch.selector
                || selector == UUPSUpgradeable.upgradeToAndCall.selector
                || selector == IModuleManager.installExecution.selector
                || selector == IModuleManager.uninstallExecution.selector
        ) {
            return address(this);
        }

        return getAccountStorage().selectorData[selector].module;
    }

    /// @inheritdoc IAccountLoupe
    function getSelectors(ModuleEntity validationFunction) external view returns (bytes4[] memory) {
        uint256 length = getAccountStorage().validationData[validationFunction].selectors.length();

        bytes4[] memory selectors = new bytes4[](length);

        for (uint256 i = 0; i < length; ++i) {
            selectors[i] = toSelector(getAccountStorage().validationData[validationFunction].selectors.at(i));
        }

        return selectors;
    }

    /// @inheritdoc IAccountLoupe
    function getExecutionHooks(bytes4 selector)
        external
        view
        override
        returns (ExecutionHook[] memory execHooks)
    {
        EnumerableSet.Bytes32Set storage hooks = getAccountStorage().selectorData[selector].executionHooks;
        uint256 executionHooksLength = hooks.length();

        execHooks = new ExecutionHook[](executionHooksLength);

        for (uint256 i = 0; i < executionHooksLength; ++i) {
            bytes32 key = hooks.at(i);
            HookConfig hookConfig = toHookConfig(key);
            execHooks[i] = ExecutionHook({
                hookFunction: hookConfig.moduleEntity(),
                isPreHook: hookConfig.hasPreHook(),
                isPostHook: hookConfig.hasPostHook()
            });
        }
    }

    /// @inheritdoc IAccountLoupe
    function getPermissionHooks(ModuleEntity validationFunction)
        external
        view
        override
        returns (ExecutionHook[] memory permissionHooks)
    {
        EnumerableSet.Bytes32Set storage hooks =
            getAccountStorage().validationData[validationFunction].permissionHooks;
        uint256 executionHooksLength = hooks.length();
        permissionHooks = new ExecutionHook[](executionHooksLength);
        for (uint256 i = 0; i < executionHooksLength; ++i) {
            bytes32 key = hooks.at(i);
            HookConfig hookConfig = toHookConfig(key);
            permissionHooks[i] = ExecutionHook({
                hookFunction: hookConfig.moduleEntity(),
                isPreHook: hookConfig.hasPreHook(),
                isPostHook: hookConfig.hasPostHook()
            });
        }
    }

    /// @inheritdoc IAccountLoupe
    function getPreValidationHooks(ModuleEntity validationFunction)
        external
        view
        override
        returns (ModuleEntity[] memory preValidationHooks)
    {
        preValidationHooks = getAccountStorage().validationData[validationFunction].preValidationHooks;
    }
}
