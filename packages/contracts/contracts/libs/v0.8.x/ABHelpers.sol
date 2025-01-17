// SPDX-License-Identifier: LGPL-3.0-only
// Created By: Art Blocks Inc.

pragma solidity ^0.8.0;

/**
 * @title Art Blocks Helpers Library
 * @notice This library contains helper functions for common operations in the
 * Art Blocks ecosystem of smart contracts.
 * @author Art Blocks Inc.
 */

library ABHelpers {
    uint256 constant ONE_MILLION = 1_000_000;

    /**
     * Convert token id to project id.
     * @param _tokenId The id of the token.
     */
    function tokenIdToProjectId(
        uint256 _tokenId
    ) internal pure returns (uint256) {
        // int division properly rounds down
        // @dev unchecked because will never divide by zero
        unchecked {
            return _tokenId / ONE_MILLION;
        }
    }

    /**
     * Convert token id to token number.
     * @param _tokenId The id of the token.
     */
    function tokenIdToTokenNumber(
        uint256 _tokenId
    ) internal pure returns (uint256) {
        // mod returns remainder, which is the token number
        // @dev no way to disable mod zero check in solidity, so not unchecked
        return _tokenId % ONE_MILLION;
    }

    /**
     * Convert project id and token number to token id.
     * @param _projectId The id of the project.
     * @param _tokenNumber The token number.
     */
    function tokenIdFromProjectIdAndTokenNumber(
        uint256 _projectId,
        uint256 _tokenNumber
    ) internal pure returns (uint256) {
        // @dev intentionally not unchecked to ensure overflow detection, which
        // would likley only occur in a malicious call
        return (_projectId * ONE_MILLION) + _tokenNumber;
    }
}
