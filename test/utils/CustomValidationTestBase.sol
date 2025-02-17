// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {UpgradeableModularAccount} from "../../src/account/UpgradeableModularAccount.sol";
import {ModuleEntity} from "../../src/helpers/ModuleEntityLib.sol";
import {ValidationConfigLib} from "../../src/helpers/ValidationConfigLib.sol";

import {AccountTestBase} from "./AccountTestBase.sol";

/// @dev This test contract base is used to test custom validation logic.
/// To use this, override the _initialValidationConfig function to return the desired validation configuration.
/// Then, call _customValidationSetup in the test setup.
/// Make sure to do so after any state variables that `_initialValidationConfig` relies on are set.
abstract contract CustomValidationTestBase is AccountTestBase {
    function _customValidationSetup() internal {
        (
            ModuleEntity validationFunction,
            bool isGlobal,
            bool isSignatureValidation,
            bytes4[] memory selectors,
            bytes memory installData,
            bytes[] memory hooks
        ) = _initialValidationConfig();

        address accountImplementation = address(factory.accountImplementation());

        account1 = UpgradeableModularAccount(payable(new ERC1967Proxy{salt: 0}(accountImplementation, "")));

        account1.initializeWithValidation(
            ValidationConfigLib.pack(validationFunction, isGlobal, isSignatureValidation),
            selectors,
            installData,
            hooks
        );

        vm.deal(address(account1), 100 ether);
    }

    function _initialValidationConfig()
        internal
        virtual
        returns (
            ModuleEntity validationFunction,
            bool shared,
            bool isSignatureValidation,
            bytes4[] memory selectors,
            bytes memory installData,
            bytes[] memory hooks
        );
}
