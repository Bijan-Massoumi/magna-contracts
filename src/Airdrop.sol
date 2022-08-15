// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MerkleProof} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/forge-std/src/console.sol";

struct AirdropConfig {
    address tokenAddress;
    bytes32 merkleRoot;
    address adminAddress;
    uint256 airdropStartTime;
    uint256 airdropEndTime;
    uint256 amountRemaining;
}

contract Airdrop {
    using SafeERC20 for IERC20;

    // stores airdropId
    mapping(uint256 => AirdropConfig) public airdropConfig;
    mapping(uint256 => mapping(address => bool)) public claimed;
    uint256 public nextAirdropId;

    /// ============ Events ============

    event AirdropCreated(
        uint256 airdropId,
        bytes32 merkleRoot,
        uint256 totalAmount,
        address adminAddress,
        uint256 airdropStartTime,
        uint256 airdropEndTime
    );

    event Claim(address indexed to, uint256 amount);

    /// ============ Errors ============

    /// @notice Thrown if address has already claimed
    error AlreadyClaimed();
    /// @notice Thrown if address/amount are not part of Merkle tree
    error NotInMerkle();
    /// @notice Thrown if admin attempts to drain airdrop funds before the set end time.
    error AirdropNotOver();
    /// @notice Thrown if createAirdrop is called with invalid times.
    error InvalidClaimTimes();
    /// @notice Thrown if empty root is push on-chain
    error EmptyRoot();
    /// @notice Thrown if claim is called on empty airdropId
    error InvalidAirdrop();
    /// @notice Thrown if claim is attempted outside airdrop time bounds
    error AirdropNotCurrent();
    /// @notice Thrown if drain is called by non-admin
    error NotAdmin();

    constructor() {
        nextAirdropId = 1;
    }

    /// ============ Functions ============

    /// @notice Allows claiming tokens if address is part of merkle tree
    /// @param _merkleRoot merkle root for airdrop
    /// @param _totalSum total amount of tokens allocated for airdrop
    /// @param _tokenAddress contract address for ERC20 to be airdropped
    /// @param _airdropStartTime timestamp in seconds for when the airdrop claim period begins
    /// @param _airdropEndTime timestamp in seconds for when the airdrop claim period ends
    function createAirdrop(
        bytes32 _merkleRoot,
        uint256 _totalSum,
        address _tokenAddress,
        uint256 _airdropStartTime,
        uint256 _airdropEndTime
    ) external returns (uint256) {
        uint256 airdropId = nextAirdropId;

        if (_merkleRoot == bytes32(0)) revert EmptyRoot();

        if (
            _airdropEndTime < _airdropStartTime ||
            _airdropEndTime < block.timestamp
        ) revert InvalidClaimTimes();

        airdropConfig[airdropId] = AirdropConfig(
            _tokenAddress,
            _merkleRoot,
            msg.sender,
            _airdropStartTime,
            _airdropEndTime,
            _totalSum
        );

        IERC20(_tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _totalSum
        );

        emit AirdropCreated(
            airdropId,
            _merkleRoot,
            _totalSum,
            msg.sender,
            _airdropStartTime,
            _airdropEndTime
        );

        nextAirdropId += 1;
        return airdropId;
    }

    /// @notice Allows claiming tokens if address is part of merkle tree
    /// @param _to address of claimee
    /// @param _amount of tokens owed to claimee
    /// @param _proof merkle proof to prove address and amount are in tree
    function claim(
        uint256 _airdropId,
        address _to,
        uint256 _amount,
        bytes32[] calldata _proof
    ) external {
        AirdropConfig storage merkleData = airdropConfig[_airdropId];

        // revert if invalid airdropId
        if (merkleData.merkleRoot == bytes32(0)) revert InvalidAirdrop();

        if (
            merkleData.airdropStartTime > block.timestamp ||
            merkleData.airdropEndTime < block.timestamp
        ) revert AirdropNotCurrent();

        // Throw if address has already claimed tokens
        if (claimed[_airdropId][_to]) revert AlreadyClaimed();

        // Verify merkle proof, or revert if not in tree
        bytes32 leaf = keccak256(abi.encodePacked(_to, _amount));

        bool isValidLeaf = MerkleProof.verify(
            _proof,
            merkleData.merkleRoot,
            leaf
        );
        if (!isValidLeaf) revert NotInMerkle();

        // Set address to claimed
        claimed[_airdropId][_to] = true;

        // send tokens to address
        IERC20(merkleData.tokenAddress).safeTransfer(_to, _amount);

        // if _amount > merkleData.amountRemaining, solidity will underflow revert
        merkleData.amountRemaining -= _amount;

        // Emit claim event
        emit Claim(_to, _amount);
    }

    function drainAirdropFunds(uint256 _airdropId, address _to) external {
        AirdropConfig storage merkleData = airdropConfig[_airdropId];
        if (merkleData.adminAddress != msg.sender) revert NotAdmin();

        if (merkleData.airdropEndTime > block.timestamp)
            revert AirdropNotOver();

        // send remaining tokens to address
        IERC20(merkleData.tokenAddress).safeTransfer(
            _to,
            merkleData.amountRemaining
        );
        merkleData.amountRemaining = 0;
    }
}
