// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.25;

import {ModuleEntity} from "../interfaces/IModuleManager.sol";

/// @notice Pre and post hooks for a given selector.
/// @dev It's possible for one of either `preExecHook` or `postExecHook` to be empty.
struct ExecutionHook {
    ModuleEntity hookFunction;
    bool isPreHook;
    bool isPostHook;
}

interface IAccountLoupe {
    /// @notice Get the module address for a selector.
    /// @dev If the selector is a native function, the module address will be the address of the account.
    /// @param selector The selector to get the configuration for.
    /// @return module The module address for this selector.
    function getExecutionFunctionHandler(bytes4 selector) external view returns (address module);

    /// @notice Get the selectors for a validation function.
    /// @param validationFunction The validation function to get the selectors for.
    /// @return The allowed selectors for this validation function.
    function getSelectors(ModuleEntity validationFunction) external view returns (bytes4[] memory);

    /// @notice Get the pre and post execution hooks for a selector.
    /// @param selector The selector to get the hooks for.
    /// @return The pre and post execution hooks for this selector.
    function getExecutionHooks(bytes4 selector) external view returns (ExecutionHook[] memory);

    /// @notice Get the pre and post execution hooks for a validation function.
    /// @param validationFunction The validation function to get the hooks for.
    /// @return The pre and post execution hooks for this validation function.
    function getPermissionHooks(ModuleEntity validationFunction) external view returns (ExecutionHook[] memory);

    /// @notice Get the pre user op and runtime validation hooks associated with a selector.
    /// @param validationFunction The validation function to get the hooks for.
    /// @return preValidationHooks The pre validation hooks for this selector.
    function getPreValidationHooks(ModuleEntity validationFunction)
        external
        view
        returns (ModuleEntity[] memory preValidationHooks);
}
