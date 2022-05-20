// SPDX-License-Identifier: LGPL-3.0-only
// Created By: Art Blocks Inc.

import "./IFilteredMinterV0.sol";

pragma solidity ^0.8.0;

/**
 * @title This interface extends the IFilteredMinterV0 interface in order to
 * add support for generic project minter configuration updates.
 * @dev key values represent strings of finite length encoded in 32 bytes to
 * minimize gas.
 * @author Art Blocks Inc.
 */
interface IFilteredMinterV1 is IFilteredMinterV0 {
    /// BOOL
    /**
     * @notice Generic project minter configuration event. Sets value of key
     * `_key` to `_value` for project `_projectId`.
     */
    event ConfigValueSet(uint256 indexed _projectId, bytes32 _key, bool _value);

    /**
     * @notice Generic project minter configuration event. Removes key `_key`
     * from project `_projectId`'s project minter configuration.
     */
    event ConfigValueRemoved(
        uint256 indexed _projectId,
        bytes32 _key,
        bool _value
    );

    /// UINT256
    /**
     * @notice Generic project minter configuration event. Sets value of key
     * `_key` to `_value` for project `_projectId`.
     */
    event ConfigValueSet(
        uint256 indexed _projectId,
        bytes32 _key,
        uint256 _value
    );

    /**
     * @notice Generic project minter configuration event. Removes key `_key`
     * from project `_projectId`'s project minter configuration.
     */
    event ConfigValueRemoved(
        uint256 indexed _projectId,
        bytes32 _key,
        uint256 _value
    );

    /// ADDRESS
    /**
     * @notice Generic project minter configuration event. Sets value of key
     * `_key` to `_value` for project `_projectId`.
     */
    event ConfigValueSet(
        uint256 indexed _projectId,
        bytes32 _key,
        address _value
    );

    /**
     * @notice Generic project minter configuration event. Removes key `_key`
     * from project `_projectId`'s project minter configuration.
     */
    event ConfigValueRemoved(
        uint256 indexed _projectId,
        bytes32 _key,
        address _value
    );

    /// BYTES32
    /**
     * @notice Generic project minter configuration event. Sets value of key
     * `_key` to `_value` for project `_projectId`.
     */
    event ConfigValueSet(
        uint256 indexed _projectId,
        bytes32 _key,
        bytes32 _value
    );

    /**
     * @notice Generic project minter configuration event. Removes key `_key`
     * from project `_projectId`'s project minter configuration.
     */
    event ConfigValueRemoved(
        uint256 indexed _projectId,
        bytes32 _key,
        bytes32 _value
    );

    /// STRING
    /**
     * @notice Generic project minter configuration event. Sets value of key
     * `_key` to `_value` for project `_projectId`.
     */
    event ConfigValueSet(
        uint256 indexed _projectId,
        bytes32 _key,
        string _value
    );

    /**
     * @notice Generic project minter configuration event. Removes key `_key`
     * from project `_projectId`'s project minter configuration.
     */
    event ConfigValueRemoved(
        uint256 indexed _projectId,
        bytes32 _key,
        string _value
    );

    /// PROJECT SETS
    /**
     * @notice Generic project minter configuration event. Adds projectId of
     * `_tokenAddress`-`_tokenId` to the set of projectIds at `_key` for
     * project `_projectId`.
     */
    event ConfigValueAddedToSet(
        uint256 indexed _projectId,
        bytes32 _key,
        address _tokenAddress,
        uint256 _tokenId
    );

    /**
     * @notice Generic project minter configuration event. Removes projectId of
     * `_tokenAddress`-`_tokenId` to the set of projectIds at `_key` for
     * project `_projectId`.
     */
    event ConfigValueRemovedFromSet(
        uint256 indexed _projectId,
        bytes32 _key,
        address _tokenAddress,
        uint256 _tokenId
    );
}
