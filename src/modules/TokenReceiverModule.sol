// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {ExecutionManifest, ManifestExecutionFunction} from "../interfaces/IExecution.sol";
import {ExecutionManifest, IExecution} from "../interfaces/IExecution.sol";
import {IModule, ModuleMetadata} from "../interfaces/IModule.sol";
import {BaseModule} from "./BaseModule.sol";

/// @title Token Receiver Module
/// @author ERC-6900 Authors
/// @notice This module allows modular accounts to receive various types of tokens by implementing
/// required token receiver interfaces.
contract TokenReceiverModule is BaseModule, IExecution, IERC721Receiver, IERC1155Receiver {
    string internal constant _NAME = "Token Receiver Module";
    string internal constant _VERSION = "1.0.0";
    string internal constant _AUTHOR = "ERC-6900 Authors";

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Execution functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    // ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    // ┃    Module interface functions    ┃
    // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

    /// @inheritdoc IModule
    // solhint-disable-next-line no-empty-blocks
    function onInstall(bytes calldata) external pure override {}

    /// @inheritdoc IModule
    // solhint-disable-next-line no-empty-blocks
    function onUninstall(bytes calldata) external pure override {}

    /// @inheritdoc IExecution
    function executionManifest() external pure override returns (ExecutionManifest memory) {
        ExecutionManifest memory manifest;

        manifest.executionFunctions = new ManifestExecutionFunction[](3);
        manifest.executionFunctions[0] = ManifestExecutionFunction({
            executionSelector: this.onERC721Received.selector,
            isPublic: true,
            allowGlobalValidation: false
        });
        manifest.executionFunctions[1] = ManifestExecutionFunction({
            executionSelector: this.onERC1155Received.selector,
            isPublic: true,
            allowGlobalValidation: false
        });
        manifest.executionFunctions[2] = ManifestExecutionFunction({
            executionSelector: this.onERC1155BatchReceived.selector,
            isPublic: true,
            allowGlobalValidation: false
        });

        manifest.interfaceIds = new bytes4[](2);
        manifest.interfaceIds[0] = type(IERC721Receiver).interfaceId;
        manifest.interfaceIds[1] = type(IERC1155Receiver).interfaceId;

        return manifest;
    }

    /// @inheritdoc IModule
    function moduleMetadata() external pure virtual override returns (ModuleMetadata memory) {
        ModuleMetadata memory metadata;
        metadata.name = _NAME;
        metadata.version = _VERSION;
        metadata.author = _AUTHOR;
        return metadata;
    }
}
