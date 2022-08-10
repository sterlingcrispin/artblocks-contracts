// SPDX-License-Identifier: LGPL-3.0-only
// Created By: Art Blocks Inc.

import "./interfaces/0.8.x/IRandomizer.sol";
import "./interfaces/0.8.x/IAdminACLV0.sol";
import "./interfaces/0.8.x/IGenArt721CoreContractV3.sol";

import "@openzeppelin-4.7/contracts/utils/Strings.sol";
import "@openzeppelin-4.7/contracts/access/Ownable.sol";
import "@openzeppelin-4.7/contracts/token/ERC721/ERC721.sol";

pragma solidity 0.8.9;

/**
 * @title Art Blocks ERC-721 core contract, V3.
 * @author Art Blocks Inc.
 */
contract GenArt721CoreV3 is ERC721, Ownable, IGenArt721CoreContractV3 {
    event ProposedArtistAddressesAndSplits(
        uint256 indexed _projectId,
        address _artistAddress,
        address _additionalPayeePrimarySales,
        uint256 _additionalPayeePrimarySalesPercentage,
        address _additionalPayeeSecondarySales,
        uint256 _additionalPayeeSecondarySalesPercentage
    );

    event AcceptedArtistAddressesAndSplits(uint256 indexed _projectId);

    uint256 constant ONE_MILLION = 1_000_000;
    uint256 constant FOUR_WEEKS_IN_SECONDS = 2_419_200;

    // generic platform event fields
    bytes32 constant FIELD_ARTBLOCKS_ADDRESS = "artblocksAddress";
    bytes32 constant FIELD_RANDOMIZER_ADDRESS = "randomizerAddress";
    bytes32 constant FIELD_ARTBLOCKS_CURATION_REGISTRY_ADDRESS =
        "curationRegistryAddress";
    bytes32 constant FIELD_ARTBLOCKS_DEPENDENCY_REGISTRY_ADDRESS =
        "dependencyRegistryAddress";
    bytes32 constant FIELD_ARTBLOCKS_PERCENTAGE = "artblocksPercentage";
    // generic project event fields
    bytes32 constant FIELD_PROJECT_COMPLETED = "completed";
    bytes32 constant FIELD_PROJECT_ACTIVE = "active";
    bytes32 constant FIELD_ARTIST_ADDRESS = "artistAddress";
    bytes32 constant FIELD_PROJECT_PAUSED = "paused";
    bytes32 constant FIELD_PROJECT_CREATED = "created";
    bytes32 constant FIELD_PROJECT_NAME = "name";
    bytes32 constant FIELD_ARTIST_NAME = "artistName";
    bytes32 constant FIELD_SECONDARY_MARKET_ROYALTY_PERCENTAGE =
        "royaltyPercentage";
    bytes32 constant FIELD_PROJECT_DESCRIPTION = "description";
    bytes32 constant FIELD_PROJECT_WEBSITE = "website";
    bytes32 constant FIELD_PROJECT_LICENSE = "license";
    bytes32 constant FIELD_MAX_INVOCATIONS = "maxInvocations";
    bytes32 constant FIELD_PROJECT_SCRIPT = "script";
    bytes32 constant FIELD_PROJECT_SCRIPT_TYPE = "scriptType";
    bytes32 constant FIELD_PROJECT_ASPECT_RATIO = "aspectRatio";
    bytes32 constant FIELD_PROJECT_IPFS_HASH = "ipfsHash";
    bytes32 constant FIELD_PROJECT_BASE_URI = "baseURI";

    // Art Blocks previous flagship ERC721 token addresses (for reference)
    /// Art Blocks Project ID range: [0-2]
    address public constant ART_BLOCKS_ERC721TOKEN_ADDRESS_V0 =
        0x059EDD72Cd353dF5106D2B9cC5ab83a52287aC3a;
    /// Art Blocks Project ID range: [3-TODO: add V1 final project ID before deploying]
    address public constant ART_BLOCKS_ERC721TOKEN_ADDRESS_V1 =
        0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270;

    /// Curation registry managed by Art Blocks
    address public artblocksCurationRegistryAddress;
    /// Dependency registry managed by Art Blocks
    address public artblocksDependencyRegistryAddress;

    /// randomizer contract
    IRandomizer public randomizerContract;

    /// admin ACL contract
    IAdminACLV0 public adminACLContract;

    struct Project {
        string name;
        string artist;
        string description;
        string website;
        string license;
        string projectBaseURI;
        string scriptType;
        string scriptTypeVersion;
        string aspectRatio;
        uint256 invocations;
        uint256 maxInvocations;
        mapping(uint256 => string) scripts;
        uint256 scriptCount;
        string ipfsHash;
        bool active;
        bool paused;
        uint256 completedTimestamp;
    }

    mapping(uint256 => Project) projects;

    // All financial functions are stripped from struct for visibility
    mapping(uint256 => address payable) public projectIdToArtistAddress;
    mapping(uint256 => address payable)
        public projectIdToAdditionalPayeePrimarySales;
    mapping(uint256 => uint256)
        public projectIdToAdditionalPayeePrimarySalesPercentage;
    mapping(uint256 => address payable)
        public projectIdToAdditionalPayeeSecondarySales;
    mapping(uint256 => uint256)
        public projectIdToAdditionalPayeeSecondarySalesPercentage;
    mapping(uint256 => uint256)
        public projectIdToSecondaryMarketRoyaltyPercentage;

    /// hash of artist's proposed payment updates to be approved by admin
    mapping(uint256 => bytes32) public proposedArtistAddressesAndSplitsHash;

    address payable public artblocksAddress;
    /// Percentage of mint revenue allocated to Art Blocks
    uint256 public artblocksPercentage = 10;

    mapping(uint256 => bytes32) public tokenIdToHash;

    /// single minter allowed for this core contract
    address public minterContract;

    /// next project ID to be created
    uint256 public nextProjectId = 0;

    /// version & type of this core contract
    string public constant coreVersion = "v3.0.0";
    string public constant coreType = "GenArt721CoreV3";

    modifier onlyValidTokenId(uint256 _tokenId) {
        require(_exists(_tokenId), "Token ID does not exist");
        _;
    }

    modifier onlyUnlocked(uint256 _projectId) {
        require(_projectUnlocked(_projectId), "Only if unlocked");
        _;
    }

    modifier onlyAdminACL(bytes4 _selector) {
        require(
            adminACLAllowed(msg.sender, address(this), _selector),
            "Only Admin ACL allowed"
        );
        _;
    }

    modifier onlyArtist(uint256 _projectId) {
        require(
            msg.sender == projectIdToArtistAddress[_projectId],
            "Only artist"
        );
        _;
    }

    modifier onlyArtistOrAdminACL(uint256 _projectId, bytes4 _selector) {
        require(
            msg.sender == projectIdToArtistAddress[_projectId] ||
                adminACLAllowed(msg.sender, address(this), _selector),
            "Only artist or Admin ACL allowed"
        );
        _;
    }

    /**
     * This modifier allows the artist of a project to call a function if the
     * owner of the contract has renounced ownership. This is to allow the
     * contract to continue to function if the owner decides to renounce
     * ownership.
     */
    modifier onlyAdminACLOrRenouncedArtist(
        uint256 _projectId,
        bytes4 _selector
    ) {
        require(
            adminACLAllowed(msg.sender, address(this), _selector) ||
                (owner() == address(0) &&
                    msg.sender == projectIdToArtistAddress[_projectId]),
            "Only Admin ACL allowed, or artist if owner has renounced"
        );
        _;
    }

    /**
     * @notice Initializes contract.
     * @param _tokenName Name of token.
     * @param _tokenSymbol Token symbol.
     * @param _randomizerContract Randomizer contract.
     * @param _adminACLContract Address of admin access control contract, to be
     * set as contract owner.
     */
    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        address _randomizerContract,
        address _adminACLContract
    ) ERC721(_tokenName, _tokenSymbol) {
        _updateArtblocksAddress(msg.sender);
        _updateRandomizerAddress(_randomizerContract);
        // set AdminACL management contract as owner
        _transferOwnership(_adminACLContract);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     * @dev Overrides and wraps OpenZeppelin's _transferOwnership function to
     * also update adminACLContract for improved introspection.
     */
    function _transferOwnership(address newOwner) internal override {
        Ownable._transferOwnership(newOwner);
        adminACLContract = IAdminACLV0(newOwner);
    }

    /**
     * @notice Updates Art Blocks payment address to `_renderProviderAddress`.
     */
    function _updateArtblocksAddress(address _artblocksAddress) internal {
        artblocksAddress = payable(_artblocksAddress);
        emit PlatformUpdated(FIELD_ARTBLOCKS_ADDRESS);
    }

    /**
     * @notice Updates randomizer address to `_randomizerAddress`.
     */
    function _updateRandomizerAddress(address _randomizerAddress) internal {
        randomizerContract = IRandomizer(_randomizerAddress);
        emit PlatformUpdated(FIELD_RANDOMIZER_ADDRESS);
    }

    /**
     * @notice Mints a token from project `_projectId` and sets the
     * token's owner to `_to`.
     * @param _to Address to be the minted token's owner.
     * @param _projectId Project ID to mint a token on.
     * @param _by Purchaser of minted token.
     * @dev sender must be the allowed minterContract
     */
    function mint(
        address _to,
        uint256 _projectId,
        address _by
    ) external returns (uint256 _tokenId) {
        require(
            msg.sender == minterContract,
            "Must mint from the allowed minter contract."
        );
        require(
            projects[_projectId].completedTimestamp == 0,
            "Must not exceed max invocations"
        );
        require(
            projects[_projectId].active ||
                _by == projectIdToArtistAddress[_projectId],
            "Project must exist and be active"
        );
        require(
            !projects[_projectId].paused ||
                _by == projectIdToArtistAddress[_projectId],
            "Purchases are paused."
        );

        return _mintToken(_to, _projectId);
    }

    function _mintToken(address _to, uint256 _projectId)
        internal
        returns (uint256 _tokenId)
    {
        // checks & effects
        // increment project's invocations, then move to memory to avoid SLOAD
        uint256 _invocationsAfter = ++projects[_projectId].invocations;
        uint256 _invocationsBefore = _invocationsAfter - 1;
        uint256 thisTokenId = (_projectId * ONE_MILLION) + _invocationsBefore;

        // mark project as completed if hit max invocations
        if (_invocationsAfter == projects[_projectId].maxInvocations) {
            _completeProject(_projectId);
        }

        bytes32 tokenHash = keccak256(
            abi.encodePacked(
                thisTokenId,
                blockhash(block.number - 1),
                randomizerContract.returnValue()
            )
        );

        tokenIdToHash[thisTokenId] = tokenHash;

        // interactions
        _mint(_to, thisTokenId);

        // Do not need to also log `projectId` in event, as the `projectId` for
        // a given token can be derived from the `tokenId` with:
        //   projectId = tokenId / 1_000_000
        emit Mint(_to, thisTokenId);

        return thisTokenId;
    }

    /**
     * @notice Internal function that returns whether a project is unlocked.
     * Projects automatically lock four weeks after they are completed.
     * Projects are considered completed when they have been invoked the
     * maximum number of times.
     * @param _projectId Project ID to check.
     */
    function _projectUnlocked(uint256 _projectId) internal view returns (bool) {
        uint256 projectCompletedTimestamp = projects[_projectId]
            .completedTimestamp;
        bool projectOpen = projectCompletedTimestamp == 0;
        return
            projectOpen ||
            (block.timestamp - projectCompletedTimestamp <
                FOUR_WEEKS_IN_SECONDS);
    }

    /**
     * @notice Internal function to complete a project.
     */
    function _completeProject(uint256 _projectId) internal {
        projects[_projectId].completedTimestamp = block.timestamp;
        emit ProjectUpdated(_projectId, FIELD_PROJECT_COMPLETED);
    }

    /**
     * @notice Updates reference to Art Blocks Curation Registry contract.
     */
    function updateArtblocksCurationRegistryAddress(
        address _artblocksCurationRegistryAddress
    )
        external
        onlyAdminACL(this.updateArtblocksCurationRegistryAddress.selector)
    {
        artblocksCurationRegistryAddress = _artblocksCurationRegistryAddress;
        emit PlatformUpdated(FIELD_ARTBLOCKS_CURATION_REGISTRY_ADDRESS);
    }

    /**
     * @notice Updates reference to Art Blocks Dependency Registry contract.
     */
    function updateArtblocksDependencyRegistryAddress(
        address _artblocksDependencyRegistryAddress
    )
        external
        onlyAdminACL(this.updateArtblocksDependencyRegistryAddress.selector)
    {
        artblocksDependencyRegistryAddress = _artblocksDependencyRegistryAddress;
        emit PlatformUpdated(FIELD_ARTBLOCKS_DEPENDENCY_REGISTRY_ADDRESS);
    }

    /**
     * @notice Updates artblocksAddress to `_artblocksAddress`.
     */
    function updateArtblocksAddress(address payable _artblocksAddress)
        public
        onlyAdminACL(this.updateArtblocksAddress.selector)
    {
        _updateArtblocksAddress(_artblocksAddress);
    }

    /**
     * @notice Updates Art Blocks mint revenue percentage to
     * `_artblocksPercentage`.
     */
    function updateArtblocksPercentage(uint256 _artblocksPercentage)
        public
        onlyAdminACL(this.updateArtblocksPercentage.selector)
    {
        require(_artblocksPercentage <= 25, "Max of 25%");
        artblocksPercentage = _artblocksPercentage;
        emit PlatformUpdated(FIELD_ARTBLOCKS_PERCENTAGE);
    }

    /**
     * @notice updates minter to `_address`.
     */
    function updateMinterContract(address _address)
        public
        onlyAdminACL(this.updateMinterContract.selector)
    {
        minterContract = _address;
        emit MinterUpdated(_address);
    }

    /**
     * @notice Updates randomizer to `_randomizerAddress`.
     */
    function updateRandomizerAddress(address _randomizerAddress)
        public
        onlyAdminACL(this.updateRandomizerAddress.selector)
    {
        _updateRandomizerAddress(_randomizerAddress);
    }

    /**
     * @notice Toggles project `_projectId` as active/inactive.
     */
    function toggleProjectIsActive(uint256 _projectId)
        public
        onlyAdminACL(this.toggleProjectIsActive.selector)
    {
        projects[_projectId].active = !projects[_projectId].active;
        emit ProjectUpdated(_projectId, FIELD_PROJECT_ACTIVE);
    }

    /**
     * @notice Artist proposes updated set of artist address, additional payee
     * addresses, and percentage splits for project `_projectId`. Addresses and
     * percentages do not have to all be changed, but they must all be defined
     * as a complete set.
     * @param _projectId Project ID.
     * @param _artistAddress Artist address that controls the project, and may
     * receive payments.
     * @param _additionalPayeePrimarySales Address that may receive a
     * percentage split of the artit's primary sales revenue.
     * @param _additionalPayeePrimarySalesPercentage Percent of artist's
     * portion of primary sale revenue that will be split to address
     * `_additionalPayeePrimarySales`.
     * @param _additionalPayeeSecondarySales Address that may receive a percentage
     * split of the secondary sales royalties.
     * @param _additionalPayeeSecondarySalesPercentage Percent of artist's portion
     * of secondary sale royalties that will be split to address
     * `_additionalPayeeSecondarySales`.
     */
    function proposeArtistPaymentAddressesAndSplits(
        uint256 _projectId,
        address payable _artistAddress,
        address payable _additionalPayeePrimarySales,
        uint256 _additionalPayeePrimarySalesPercentage,
        address payable _additionalPayeeSecondarySales,
        uint256 _additionalPayeeSecondarySalesPercentage
    ) external onlyArtist(_projectId) {
        // checks
        require(
            _additionalPayeePrimarySalesPercentage <= 100 &&
                _additionalPayeeSecondarySalesPercentage <= 100,
            "Max of 100%"
        );
        // effects
        proposedArtistAddressesAndSplitsHash[_projectId] = keccak256(
            abi.encodePacked(
                _artistAddress,
                _additionalPayeePrimarySales,
                _additionalPayeePrimarySalesPercentage,
                _additionalPayeeSecondarySales,
                _additionalPayeeSecondarySalesPercentage
            )
        );
        // emit event for off-chain indexing
        emit ProposedArtistAddressesAndSplits(
            _projectId,
            _artistAddress,
            _additionalPayeePrimarySales,
            _additionalPayeePrimarySalesPercentage,
            _additionalPayeeSecondarySales,
            _additionalPayeeSecondarySalesPercentage
        );
    }

    /**
     * @notice Admin accepts a proposed set of updated artist address,
     * additional payee addresses, and percentage splits for project
     * `_projectId`. Addresses and percentages do not have to all be changed,
     * but they must all be defined as a complete set.
     * @param _projectId Project ID.
     * @param _artistAddress Artist address that controls the project, and may
     * receive payments.
     * @param _additionalPayeePrimarySales Address that may receive a
     * percentage split of the artit's primary sales revenue.
     * @param _additionalPayeePrimarySalesPercentage Percent of artist's
     * portion of primary sale revenue that will be split to address
     * `_additionalPayeePrimarySales`.
     * @param _additionalPayeeSecondarySales Address that may receive a percentage
     * split of the secondary sales royalties.
     * @param _additionalPayeeSecondarySalesPercentage Percent of artist's portion
     * of secondary sale royalties that will be split to address
     * `_additionalPayeeSecondarySales`.
     * @dev this must be called by the Admin ACL contract, and must only accept
     * the most recent proposed values for a given project (validated on-chain
     * by comparing the hash of the proposed and accepted values).
     */
    function adminAcceptArtistAddressesAndSplits(
        uint256 _projectId,
        address payable _artistAddress,
        address payable _additionalPayeePrimarySales,
        uint256 _additionalPayeePrimarySalesPercentage,
        address payable _additionalPayeeSecondarySales,
        uint256 _additionalPayeeSecondarySalesPercentage
    )
        external
        onlyAdminACLOrRenouncedArtist(
            _projectId,
            this.adminAcceptArtistAddressesAndSplits.selector
        )
    {
        // checks
        require(
            proposedArtistAddressesAndSplitsHash[_projectId] ==
                keccak256(
                    abi.encodePacked(
                        _artistAddress,
                        _additionalPayeePrimarySales,
                        _additionalPayeePrimarySalesPercentage,
                        _additionalPayeeSecondarySales,
                        _additionalPayeeSecondarySalesPercentage
                    )
                ),
            "Must match artist proposal"
        );
        // effects
        projectIdToArtistAddress[_projectId] = _artistAddress;
        projectIdToAdditionalPayeePrimarySales[
            _projectId
        ] = _additionalPayeePrimarySales;
        projectIdToAdditionalPayeePrimarySalesPercentage[
            _projectId
        ] = _additionalPayeePrimarySalesPercentage;
        projectIdToAdditionalPayeeSecondarySales[
            _projectId
        ] = _additionalPayeeSecondarySales;
        projectIdToAdditionalPayeeSecondarySalesPercentage[
            _projectId
        ] = _additionalPayeeSecondarySalesPercentage;
        // emit event for off-chain indexing
        emit AcceptedArtistAddressesAndSplits(_projectId);
    }

    /**
     * @notice Updates artist of project `_projectId` to `_artistAddress`.
     * This is to only be used in the event that the artist address is
     * compromised or sanctioned.
     */
    function updateProjectArtistAddress(
        uint256 _projectId,
        address payable _artistAddress
    ) public onlyAdminACL(this.updateProjectArtistAddress.selector) {
        projectIdToArtistAddress[_projectId] = _artistAddress;
        emit ProjectUpdated(_projectId, FIELD_ARTIST_ADDRESS);
    }

    /**
     * @notice Toggles paused state of project `_projectId`.
     */
    function toggleProjectIsPaused(uint256 _projectId)
        public
        onlyArtist(_projectId)
    {
        projects[_projectId].paused = !projects[_projectId].paused;
        emit ProjectUpdated(_projectId, FIELD_PROJECT_PAUSED);
    }

    /**
     * @notice Adds new project `_projectName` by `_artistAddress`.
     * @param _projectName Project name.
     * @param _artistAddress Artist's address.
     * @dev token price now stored on minter
     */
    function addProject(
        string memory _projectName,
        address payable _artistAddress
    ) public onlyAdminACL(this.addProject.selector) {
        uint256 projectId = nextProjectId;
        projectIdToArtistAddress[projectId] = _artistAddress;
        projects[projectId].name = _projectName;
        projects[projectId].paused = true;
        projects[projectId].maxInvocations = ONE_MILLION;

        nextProjectId = nextProjectId + 1;
        emit ProjectUpdated(projectId, FIELD_PROJECT_CREATED);
    }

    /**
     * @notice Updates name of project `_projectId` to be `_projectName`.
     */
    function updateProjectName(uint256 _projectId, string memory _projectName)
        public
        onlyUnlocked(_projectId)
        onlyArtistOrAdminACL(_projectId, this.updateProjectName.selector)
    {
        projects[_projectId].name = _projectName;
        emit ProjectUpdated(_projectId, FIELD_PROJECT_NAME);
    }

    /**
     * @notice Updates artist name for project `_projectId` to be
     * `_projectArtistName`.
     */
    function updateProjectArtistName(
        uint256 _projectId,
        string memory _projectArtistName
    )
        public
        onlyUnlocked(_projectId)
        onlyArtistOrAdminACL(_projectId, this.updateProjectArtistName.selector)
    {
        projects[_projectId].artist = _projectArtistName;
        emit ProjectUpdated(_projectId, FIELD_ARTIST_NAME);
    }

    /**
     * @notice Updates artist secondary market royalties for project
     * `_projectId` to be `_secondMarketRoyalty` percent.
     * This DOES NOT include the secondary market royalty percentages collected
     * by Art Blocks; this is only the total percentage of royalties that will
     * be split to artist and additionalSecondaryPayee.
     * @param _projectId Project ID.
     * @param _secondMarketRoyalty Percent of secondary sales revenue that will
     * be split to artist and additionalSecondaryPayee. This must be less than
     * or equal to 95 percent.
     */
    function updateProjectSecondaryMarketRoyaltyPercentage(
        uint256 _projectId,
        uint256 _secondMarketRoyalty
    ) public onlyArtist(_projectId) {
        require(_secondMarketRoyalty <= 95, "Max of 95%");
        projectIdToSecondaryMarketRoyaltyPercentage[
            _projectId
        ] = _secondMarketRoyalty;
        emit ProjectUpdated(
            _projectId,
            FIELD_SECONDARY_MARKET_ROYALTY_PERCENTAGE
        );
    }

    /**
     * @notice Updates description of project `_projectId`.
     * Only artist may call when unlocked, only admin may call when locked.
     */
    function updateProjectDescription(
        uint256 _projectId,
        string memory _projectDescription
    ) public {
        // checks
        require(
            _projectUnlocked(_projectId)
                ? msg.sender == projectIdToArtistAddress[_projectId]
                : adminACLAllowed(
                    msg.sender,
                    address(this),
                    this.updateProjectDescription.selector
                ),
            "Only artist when unlocked, owner when locked"
        );
        // effects
        projects[_projectId].description = _projectDescription;
        emit ProjectUpdated(_projectId, FIELD_PROJECT_DESCRIPTION);
    }

    /**
     * @notice Updates website of project `_projectId` to be `_projectWebsite`.
     */
    function updateProjectWebsite(
        uint256 _projectId,
        string memory _projectWebsite
    ) public onlyArtist(_projectId) {
        projects[_projectId].website = _projectWebsite;
        emit ProjectUpdated(_projectId, FIELD_PROJECT_WEBSITE);
    }

    /**
     * @notice Updates license for project `_projectId`.
     */
    function updateProjectLicense(
        uint256 _projectId,
        string memory _projectLicense
    )
        public
        onlyUnlocked(_projectId)
        onlyArtistOrAdminACL(_projectId, this.updateProjectLicense.selector)
    {
        projects[_projectId].license = _projectLicense;
        emit ProjectUpdated(_projectId, FIELD_PROJECT_LICENSE);
    }

    /**
     * @notice Updates maximum invocations for project `_projectId` to
     * `_maxInvocations`. Maximum invocations may only be decreased by the
     * artist, and must be greater than or equal to current invocations.
     * New projects are created with maximum invocations of 1 million by
     * default.
     */
    function updateProjectMaxInvocations(
        uint256 _projectId,
        uint256 _maxInvocations
    ) public onlyArtist(_projectId) {
        // checks
        require(
            (_maxInvocations < projects[_projectId].maxInvocations),
            "maxInvocations may only be decreased"
        );
        require(
            _maxInvocations >= projects[_projectId].invocations,
            "Only max invocations gte current invocations"
        );
        // effects
        projects[_projectId].maxInvocations = _maxInvocations;
        emit ProjectUpdated(_projectId, FIELD_MAX_INVOCATIONS);

        // register completed timestamp if action completed the project
        if (_maxInvocations == projects[_projectId].invocations) {
            _completeProject(_projectId);
        }
    }

    /**
     * @notice Adds a script to project `_projectId`.
     * @param _projectId Project to be updated.
     * @param _script Script to be added.
     */
    function addProjectScript(uint256 _projectId, string memory _script)
        public
        onlyUnlocked(_projectId)
        onlyArtistOrAdminACL(_projectId, this.addProjectScript.selector)
    {
        projects[_projectId].scripts[
            projects[_projectId].scriptCount
        ] = _script;
        projects[_projectId].scriptCount = projects[_projectId].scriptCount + 1;
        emit ProjectUpdated(_projectId, FIELD_PROJECT_SCRIPT);
    }

    /**
     * @notice Updates script for project `_projectId` at script ID `_scriptId`.
     * @param _projectId Project to be updated.
     * @param _scriptId Script ID to be updated.
     * @param _script Script to be added.
     */
    function updateProjectScript(
        uint256 _projectId,
        uint256 _scriptId,
        string memory _script
    )
        public
        onlyUnlocked(_projectId)
        onlyArtistOrAdminACL(_projectId, this.updateProjectScript.selector)
    {
        require(
            _scriptId < projects[_projectId].scriptCount,
            "scriptId out of range"
        );
        projects[_projectId].scripts[_scriptId] = _script;
        emit ProjectUpdated(_projectId, FIELD_PROJECT_SCRIPT);
    }

    /**
     * @notice Removes last script from project `_projectId`.
     */
    function removeProjectLastScript(uint256 _projectId)
        public
        onlyUnlocked(_projectId)
        onlyArtistOrAdminACL(_projectId, this.removeProjectLastScript.selector)
    {
        require(
            projects[_projectId].scriptCount > 0,
            "there are no scripts to remove"
        );
        delete projects[_projectId].scripts[
            projects[_projectId].scriptCount - 1
        ];
        projects[_projectId].scriptCount = projects[_projectId].scriptCount - 1;
        emit ProjectUpdated(_projectId, FIELD_PROJECT_SCRIPT);
    }

    /**
     * @notice Updates script type for project `_projectId`.
     * @param _projectId Project to be updated.
     * @param _scriptType Libary to be injected by renderer. e.g. "p5js"
     * @param _scriptTypeVersion Version of library to be injected. e.g. "1.0.0"
     */
    function updateProjectScriptType(
        uint256 _projectId,
        string memory _scriptType,
        string memory _scriptTypeVersion
    )
        public
        onlyUnlocked(_projectId)
        onlyArtistOrAdminACL(_projectId, this.updateProjectScriptType.selector)
    {
        projects[_projectId].scriptType = _scriptType;
        projects[_projectId].scriptTypeVersion = _scriptTypeVersion;
        emit ProjectUpdated(_projectId, FIELD_PROJECT_SCRIPT_TYPE);
    }

    /**
     * @notice Updates project's aspect ratio.
     * @param _projectId Project to be updated.
     * @param _aspectRatio Aspect ratio to be set. Intended to be string in the
     * format of a decimal, e.g. "1" for square, "1.77777778" for 16:9, etc.
     */
    function updateProjectAspectRatio(
        uint256 _projectId,
        string memory _aspectRatio
    )
        public
        onlyUnlocked(_projectId)
        onlyArtistOrAdminACL(_projectId, this.updateProjectAspectRatio.selector)
    {
        projects[_projectId].aspectRatio = _aspectRatio;
        emit ProjectUpdated(_projectId, FIELD_PROJECT_ASPECT_RATIO);
    }

    /**
     * @notice Updates ipfs hash for project `_projectId`.
     */
    function updateProjectIpfsHash(uint256 _projectId, string memory _ipfsHash)
        public
        onlyUnlocked(_projectId)
        onlyArtistOrAdminACL(_projectId, this.updateProjectIpfsHash.selector)
    {
        projects[_projectId].ipfsHash = _ipfsHash;
        emit ProjectUpdated(_projectId, FIELD_PROJECT_IPFS_HASH);
    }

    /**
     * @notice Updates base URI for project `_projectId` to `_newBaseURI`.
     */
    function updateProjectBaseURI(uint256 _projectId, string memory _newBaseURI)
        public
        onlyArtist(_projectId)
    {
        projects[_projectId].projectBaseURI = _newBaseURI;
        emit ProjectUpdated(_projectId, FIELD_PROJECT_BASE_URI);
    }

    /**
     * @notice Convenience function that returns whether `_sender` is allowed
     * to call function with selector `_selector` on contract `_contract`, as
     * determined by this contract's current Admin ACL contract. Expected use
     * cases include minter contracts checking if caller is allowed to call
     * admin-gated functions on minter contracts.
     * @param _sender Address of the sender calling function with selector
     * `_selector` on contract `_contract`.
     * @param _contract Address of the contract being called by `_sender`.
     * @param _selector Function selector of the function being called by
     * `_sender`.
     * @dev assumes the Admin ACL contract is the owner of this contract, which
     * is expected to always be true.
     * @dev adminACLContract is expected to either be null address (if owner
     * has renounced ownership), or conform to IAdminACLV0 interface. Check for
     * null address first to avoid revert when admin has renounced ownership.
     */
    function adminACLAllowed(
        address _sender,
        address _contract,
        bytes4 _selector
    ) public returns (bool) {
        return
            owner() != address(0) &&
            adminACLContract.allowed(_sender, _contract, _selector);
    }

    /**
     * @notice Returns project details for project `_projectId`.
     * @param _projectId Project to be queried.
     * @return projectName Name of project
     * @return artist Artist of project
     * @return description Project description
     * @return website Project website
     * @return license Project license
     * @dev this function was named projectDetails prior to V3 core contract.
     */
    function projectDetails(uint256 _projectId)
        public
        view
        returns (
            string memory projectName,
            string memory artist,
            string memory description,
            string memory website,
            string memory license
        )
    {
        projectName = projects[_projectId].name;
        artist = projects[_projectId].artist;
        description = projects[_projectId].description;
        website = projects[_projectId].website;
        license = projects[_projectId].license;
    }

    /**
     * @notice Returns project state data for project `_projectId`.
     * @param _projectId Project to be queried
     * @return invocations Current number of invocations
     * @return maxInvocations Maximum allowed invocations
     * @return active Boolean representing if project is currently active
     * @return paused Boolean representing if project is paused
     * @return locked Boolean representing if project is locked
     * @dev price and currency info are located on minter contracts
     */
    function projectStateData(uint256 _projectId)
        public
        view
        returns (
            uint256 invocations,
            uint256 maxInvocations,
            bool active,
            bool paused,
            bool locked
        )
    {
        invocations = projects[_projectId].invocations;
        maxInvocations = projects[_projectId].maxInvocations;
        active = projects[_projectId].active;
        paused = projects[_projectId].paused;
        locked = !_projectUnlocked(_projectId);
    }

    /**
     * @notice Returns artist payment information for project `_projectId`.
     * @param _projectId Project to be queried
     * @return artistAddress Project Artist's address
     * @return additionalPayeePrimarySales Additional payee address for primary
     * sales
     * @return additionalPayeePrimarySalesPercentage Percentage of artist revenue
     * to be sent to the additional payee address for primary sales
     * @return additionalPayeeSecondarySales Additional payee address for secondary
     * sales royalties
     * @return additionalPayeeSecondarySalesPercentage Percentage of artist revenue
     * to be sent to the additional payee address for secondary sales royalties

     */
    function projectArtistPaymentInfo(uint256 _projectId)
        public
        view
        returns (
            address artistAddress,
            address additionalPayeePrimarySales,
            uint256 additionalPayeePrimarySalesPercentage,
            address additionalPayeeSecondarySales,
            uint256 additionalPayeeSecondarySalesPercentage
        )
    {
        artistAddress = projectIdToArtistAddress[_projectId];
        additionalPayeePrimarySales = projectIdToAdditionalPayeePrimarySales[
            _projectId
        ];
        additionalPayeePrimarySalesPercentage = projectIdToAdditionalPayeePrimarySalesPercentage[
            _projectId
        ];
        additionalPayeeSecondarySales = projectIdToAdditionalPayeeSecondarySales[
            _projectId
        ];
        additionalPayeeSecondarySalesPercentage = projectIdToAdditionalPayeeSecondarySalesPercentage[
            _projectId
        ];
    }

    /**
     * @notice Returns script information for project `_projectId`.
     * @param _projectId Project to be queried.
     * @return scriptType Project's script type/library (e.g. "p5js")
     * @return scriptTypeVersion Project's library version (e.g. "1.0.0")
     * @return aspectRatio Aspect ratio of project (e.g. "1" for square,
     * "1.77777778" for 16:9, etc.)
     * @return ipfsHash IPFS hash for project
     * @return scriptCount Count of scripts for project
     */
    function projectScriptDetails(uint256 _projectId)
        external
        view
        returns (
            string memory scriptType,
            string memory scriptTypeVersion,
            string memory aspectRatio,
            string memory ipfsHash,
            uint256 scriptCount
        )
    {
        scriptType = projects[_projectId].scriptType;
        scriptTypeVersion = projects[_projectId].scriptTypeVersion;
        aspectRatio = projects[_projectId].aspectRatio;
        scriptCount = projects[_projectId].scriptCount;
        ipfsHash = projects[_projectId].ipfsHash;
    }

    /**
     * @notice Returns script for project `_projectId` at script index `_index`.
     */
    function projectScriptByIndex(uint256 _projectId, uint256 _index)
        external
        view
        returns (string memory)
    {
        return projects[_projectId].scripts[_index];
    }

    /**
     * @notice Returns base URI for project `_projectId`.
     */
    function projectURIInfo(uint256 _projectId)
        external
        view
        returns (string memory projectBaseURI)
    {
        projectBaseURI = projects[_projectId].projectBaseURI;
    }

    /**
     * @notice Backwards-compatible (pre-V3) function returning if `_minter` is
     * minterContract.
     */
    function isMintWhitelisted(address _minter) external view returns (bool) {
        return (minterContract == _minter);
    }

    /**
     * @notice Gets royalty data for token ID `_tokenId`.
     * @param _tokenId Token ID to be queried.
     * @return artistAddress Artist's payment address
     * @return additionalPayee Additional payee's payment address
     * @return additionalPayeePercentage Percentage of artist revenue
     * to be sent to the additional payee's address
     * @return royaltyFeeByID Total royalty percentage to be sent to
     * combination of artist and additional payee
     */
    function getRoyaltyData(uint256 _tokenId)
        public
        view
        returns (
            address artistAddress,
            address additionalPayee,
            uint256 additionalPayeePercentage,
            uint256 royaltyFeeByID
        )
    {
        uint256 projectId = _tokenId / ONE_MILLION;
        artistAddress = projectIdToArtistAddress[projectId];
        additionalPayee = projectIdToAdditionalPayeeSecondarySales[projectId];
        additionalPayeePercentage = projectIdToAdditionalPayeeSecondarySalesPercentage[
            projectId
        ];
        royaltyFeeByID = projectIdToSecondaryMarketRoyaltyPercentage[projectId];
    }

    /**
     * @notice Gets the project ID for a given `_tokenId`.
     */
    function tokenIdToProjectId(uint256 _tokenId)
        external
        pure
        returns (uint256 _projectId)
    {
        return _tokenId / ONE_MILLION;
    }

    /**
     * @notice Gets token URI for token ID `_tokenId`.
     */
    function tokenURI(uint256 _tokenId)
        public
        view
        override
        onlyValidTokenId(_tokenId)
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    projects[_tokenId / ONE_MILLION].projectBaseURI,
                    Strings.toString(_tokenId)
                )
            );
    }

    /**
     * @notice View function that returns appropriate revenue splits between
     * different parties given a sale price of `_price` on project
     * `_projectId`. Prescribes a split between project artist, additional
     * primary payee, and Art Blocks. Does not account for refund if user
     * overpays for a token (minter should refund the difference).
     * Some minters may have alternative methods of splitting payments, in
     * which case they should implement their own payment splitting logic.
     * @param _projectId Project ID to be queried.
     * @param _price Sale price of token.
     * @return recipients_ Array of recipient addresses, always in the order
     * [artist, additionalPayeePrimarySales, artblocksAddress]
     * @return revenues_ Array of recipient addresses, always in the order
     * [artistRevenue, additionalPayeePrimarySalesRevenue, artblocksRevenue]
     * @dev this always returns three addresses and three revenues, but the
     * revenue could be zero for one or more of the addresses. It is up to the
     * contract performing the revenue split to handle this appropriately.
     */
    function getPrimaryRevenueSplits(uint256 _projectId, uint256 _price)
        external
        view
        returns (
            address payable[] memory recipients_,
            uint256[] memory revenues_
        )
    {
        recipients_ = new address payable[](3);
        revenues_ = new uint256[](3);
        // calculate revenues
        uint256 _artblocksRevenue = (_price * artblocksPercentage) / 100;
        uint256 _projectFunds = _price - _artblocksRevenue;
        uint256 _additionalPayeeRevenue = (_projectFunds *
            projectIdToAdditionalPayeePrimarySalesPercentage[_projectId]) / 100;
        // Artist
        recipients_[0] = projectIdToArtistAddress[_projectId];
        revenues_[0] = _projectFunds - _additionalPayeeRevenue;
        // Additional Payee for primary sales
        recipients_[1] = projectIdToAdditionalPayeePrimarySales[_projectId];
        revenues_[1] = _additionalPayeeRevenue;
        // Art Blocks
        recipients_[2] = artblocksAddress;
        revenues_[2] = _artblocksRevenue;
    }

    /**
     * @notice Returns contract owner. Set to deployer's address by default on
     * contract deployment.
     * @dev ref: https://docs.openzeppelin.com/contracts/4.x/api/access#Ownable
     * @dev owner role was called `admin` prior to V3 core contract
     */
    function owner()
        public
        view
        override(Ownable, IGenArt721CoreContractV3)
        returns (address)
    {
        return Ownable.owner();
    }

    /**
     * @notice Backwards-compatible (pre-V3) getter returning contract admin
     * @return admin_ Address of contract owner
     */
    function admin() public view returns (address) {
        return owner();
    }
}
