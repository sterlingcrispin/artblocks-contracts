// SPDX-License-Identifier: LGPL-3.0-only
// Created By: Art Blocks Inc.

pragma solidity ^0.8.0;

import "./IEngineRegistryV1.sol";
import "./IAdminACLV0.sol";

/**
 * @title IMinterFilterV1
 * @author Art Blocks Inc.
 * @notice Interface for a new minter filter contract.
 * This interface does not extend the previous version of the minter filter
 * interface, as the previous version is not compatible with the new
 * minter filter architecture.
 * @dev This interface is for a minter filter that supports multiple core
 * contracts, and allows for a minter to be set on a per-project basis.
 */
interface IMinterFilterV1 {
    /**
     * @notice Emitted when contract is deployed to notify indexing services
     * of the new contract deployment.
     */
    event Deployed();

    /**
     * @notice Globally approved minter `_minter`.
     */
    event MinterApprovedGlobally(address indexed _minter, string _minterType);

    /**
     * @notice Globally revoked minter `_minter`.
     * @dev contract owner may still approve this minter on a per-contract
     * basis.
     */
    event MinterRevokedGlobally(address indexed _minter);

    /**
     * @notice Approved minter `_minter` on core contract
     * `_coreContract`.
     */
    event MinterApprovedForContract(
        address indexed _coreContract,
        address indexed _minter,
        string _minterType
    );

    /**
     * @notice Globally revoked minter `_minter`.
     * @dev minter filter owner may still globally approve this minter for all
     * contracts.
     */
    event MinterRevokedForContract(
        address indexed _coreContract,
        address indexed _minter
    );

    /**
     * @notice Minter at address `minter` set as minter for project
     * `projectId` on core contract `coreContract`.
     */
    event ProjectMinterRegistered(
        uint256 indexed projectId,
        address indexed coreContract,
        address indexed minter,
        string _minterType
    );

    /**
     * @notice Minter removed for project `projectId` on core contract
     * `coreContract`.
     */
    event ProjectMinterRemoved(
        uint256 indexed projectId,
        address indexed coreContract
    );

    /**
     * @notice Admin ACL contract updated to `adminACLContract`.
     */
    event AdminACLUpdated(address indexed adminACLContract);

    /**
     * @notice Engine Registry contract updated to `engineRegistry`.
     */
    event EngineRegistryUpdated(address indexed engineRegistry);

    function setMinterForProject(
        uint256 _projectId,
        address _coreContract,
        address _minter
    ) external;

    function removeMinterForProject(
        uint256 _projectId,
        address _coreContract
    ) external;

    // @dev function name is optimized for gas
    function mint_joo(
        address _to,
        uint256 _projectId,
        address _coreContract,
        address _sender
    ) external returns (uint256);

    function updateEngineRegistry(address _engineRegistry) external;

    function getMinterForProject(
        uint256 _projectId,
        address _coreContract
    ) external view returns (address);

    function projectHasMinter(
        uint256 _projectId,
        address _coreContract
    ) external view returns (bool);

    /**
     * @notice View that returns if a core contract is registered with the
     * engine registry, allowing this minter filter to service it.
     * @param _coreContract core contract address to be checked
     */
    function isRegisteredCoreContract(
        address _coreContract
    ) external view returns (bool);

    /// Address of current engine registry contract
    function engineRegistry() external view returns (IEngineRegistryV1);

    /// The current admin ACL contract
    function adminACLContract() external view returns (IAdminACLV0);

    /**
     * Owner of contract.
     * @dev This returns the address of the Admin ACL contract.
     */
    function owner() external view returns (address);
}
