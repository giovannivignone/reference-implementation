// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";

import {ExecutionManifest, IExecution, ManifestExecutionFunction} from "../../../src/interfaces/IExecution.sol";
import {ModuleMetadata} from "../../../src/interfaces/IModule.sol";

import {DIRECT_CALL_VALIDATION_ENTITYID} from "../../../src/helpers/Constants.sol";

import {IStandardExecutor} from "../../../src/interfaces/IStandardExecutor.sol";
import {IValidation} from "../../../src/interfaces/IValidation.sol";

import {BaseModule} from "../../../src/modules/BaseModule.sol";

contract RegularResultContract {
    function foo() external pure returns (bytes32) {
        return keccak256("bar");
    }

    function bar() external pure returns (bytes32) {
        return keccak256("foo");
    }
}

contract ResultCreatorModule is IExecution, BaseModule {
    function onInstall(bytes calldata) external override {}

    function onUninstall(bytes calldata) external override {}

    function foo() external pure returns (bytes32) {
        return keccak256("bar");
    }

    function bar() external pure returns (bytes32) {
        return keccak256("foo");
    }

    function executionManifest() external pure override returns (ExecutionManifest memory) {
        ExecutionManifest memory manifest;

        manifest.executionFunctions = new ManifestExecutionFunction[](2);
        manifest.executionFunctions[0] = ManifestExecutionFunction({
            executionSelector: this.foo.selector,
            isPublic: true,
            allowGlobalValidation: false
        });
        manifest.executionFunctions[1] = ManifestExecutionFunction({
            executionSelector: this.bar.selector,
            isPublic: false,
            allowGlobalValidation: false
        });

        return manifest;
    }

    function moduleMetadata() external pure override returns (ModuleMetadata memory) {}
}

contract ResultConsumerModule is IExecution, BaseModule, IValidation {
    ResultCreatorModule public immutable RESULT_CREATOR;
    RegularResultContract public immutable REGULAR_RESULT_CONTRACT;

    error NotAuthorized();

    constructor(ResultCreatorModule _resultCreator, RegularResultContract _regularResultContract) {
        RESULT_CREATOR = _resultCreator;
        REGULAR_RESULT_CONTRACT = _regularResultContract;
    }

    // Validation function implementations. We only care about the runtime validation function, to authorize
    // itself.

    function validateUserOp(uint32, PackedUserOperation calldata, bytes32) external pure returns (uint256) {
        revert NotImplemented();
    }

    function validateRuntime(address, uint32, address sender, uint256, bytes calldata, bytes calldata)
        external
        view
    {
        if (sender != address(this)) {
            revert NotAuthorized();
        }
    }

    function validateSignature(address, uint32, address, bytes32, bytes calldata) external pure returns (bytes4) {
        revert NotImplemented();
    }

    // Check the return data through the fallback
    function checkResultFallback(bytes32 expected) external view returns (bool) {
        // This result should be allowed based on the manifest permission request
        bytes32 actual = ResultCreatorModule(msg.sender).foo();

        return actual == expected;
    }

    // Check the return data through the execute with authorization case
    function checkResultExecuteWithAuthorization(address target, bytes32 expected) external returns (bool) {
        // This result should be allowed based on the manifest permission request
        bytes memory returnData = IStandardExecutor(msg.sender).executeWithAuthorization(
            abi.encodeCall(IStandardExecutor.execute, (target, 0, abi.encodeCall(RegularResultContract.foo, ()))),
            abi.encodePacked(this, DIRECT_CALL_VALIDATION_ENTITYID, uint8(0), uint32(1), uint8(255)) // Validation
                // function of self,
                // selector-associated, with no auth data
        );

        bytes32 actual = abi.decode(abi.decode(returnData, (bytes)), (bytes32));

        return actual == expected;
    }

    function onInstall(bytes calldata) external override {}

    function onUninstall(bytes calldata) external override {}

    function executionManifest() external pure override returns (ExecutionManifest memory) {
        ExecutionManifest memory manifest;

        manifest.executionFunctions = new ManifestExecutionFunction[](2);
        manifest.executionFunctions[0] = ManifestExecutionFunction({
            executionSelector: this.checkResultFallback.selector,
            isPublic: true,
            allowGlobalValidation: false
        });
        manifest.executionFunctions[1] = ManifestExecutionFunction({
            executionSelector: this.checkResultExecuteWithAuthorization.selector,
            isPublic: true,
            allowGlobalValidation: false
        });

        return manifest;
    }

    function moduleMetadata() external pure override returns (ModuleMetadata memory) {}
}
