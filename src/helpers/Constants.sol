// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

// Index marking the start of the data for the validation function.
uint8 constant RESERVED_VALIDATION_DATA_INDEX = type(uint8).max;

// Maximum number of pre-validation hooks that can be registered.
uint8 constant MAX_PRE_VALIDATION_HOOKS = type(uint8).max;

// Magic value for the Entity ID of direct call validation.
uint32 constant DIRECT_CALL_VALIDATION_ENTITYID = type(uint32).max;
