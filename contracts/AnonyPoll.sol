//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ByteHasher } from "./helpers/ByteHasher.sol";
import { IWorldID } from "./interfaces/IWorldID.sol";

contract AnonyPoll {
  using ByteHasher for bytes;

  /// The World ID instance that will be used for verifying proofs
  IWorldID internal immutable worldId;
  /// The contract's external nullifier hash
  uint256 internal immutable externalNullifier;
  /// The World ID group ID (always 1)
  uint256 internal immutable groupId = 1;

  struct Poll {
    address owner; // Owner of the poll, may end the poll
    bool ended; // If the poll has ended or not
    string question; // Question of the poll, what do you want to learn?
    uint choiceCount; // Number of choices the poll has
  }

  /// Thrown when attempting to reuse a nullifier.
  error InvalidNullifier();
  /// You cannot end a poll that is not created by you.
  error PollOwnerAuthentication();
  /// You may have at most `MAX_POLL_COUNT_PER_WALLOT` polls per wallot.
  error MaxPollCountReached(uint8 MAX_POLL_COUNT_PER_WALLOT);
  /// You have already voted using this nullifier under this poll.
  error AlreadyVoted();
  /// You seem to send an unvalid choice index, your choice must be in between [0, `choiceCount`], inclusive.
  error ChoiceOutOfRange(uint choiceCount);
  /// This poll has ended, you may not vote anymore.
  error PollIsEnded();

  uint8 public constant MAX_POLL_COUNT_PER_WALLOT = 100; // Max poll count a wallot may have. TODO: Implement a delete function on polls.
  uint64 public totalPollCount; // Total poll count on the contract, not functional

  mapping(uint256 => Poll) polls; // List of polls
  mapping(address => uint8) pollCount; // Number of polls on each wallot address
  mapping(uint256 => mapping(uint => string)) choiceNames; // Map of choice names for each choice index
  mapping(uint256 => mapping(uint => uint64)) choiceVoteCounts; // Number of votes on each choice index
  mapping(uint256 => mapping(uint256 => bool)) hasVoted; // Information if a person has voted before or not, kept with WorldIdNullfier

  event newVote(uint256 id, string name); // Emit newVote event to count votes on frontend asynchronously

  // Contruct the contract with WorldID contracts
  constructor(
    IWorldID _worldId, // The WorldID instance that will verify the proofs
    string memory _appId, // The World ID app ID
    string memory _actionId // The World ID action ID
  ) {
    worldId = _worldId;
    externalNullifier = abi
      .encodePacked(abi.encodePacked(_appId).hashToField(), _actionId)
      .hashToField();
  } 

  // Verify the sender is a human and create a new poll
  // "Because only people may have a question"
  function verifyAndCreatePoll(
    string calldata question, // Question of the poll, what do you want to learn?
    string[] calldata choices, // List of choices under the poll 
    address signal, // An arbitrary input from the user, usually the user's wallet address (check README for further details)
    uint256 root, // The root of the Merkle tree (returned by the JS widget).
    uint256 nullifierHash, // The nullifier hash for this proof, preventing double signaling (returned by the JS widget).
    uint256[8] calldata proof // The zero-knowledge proof that demonstrates the claimer is registered with World ID (returned by the JS widget).
  ) public returns (uint256) {
    uint256 uniquePollId = uint256(block.timestamp) + uint256(uint160(msg.sender)); // Generate a unique poll id using block timestamp and sender wallot address
    uint8 userPollCount = pollCount[msg.sender]; // Get this users poll count

    if (userPollCount >= MAX_POLL_COUNT_PER_WALLOT) // A person may have at most `MAX_POLL_COUNT_PER_WALLOT` polls
      revert MaxPollCountReached(MAX_POLL_COUNT_PER_WALLOT);

    // Verify the provided proof is valid and the user is verified by World ID
    worldId.verifyProof(
      root,
      groupId,
      abi.encodePacked(signal).hashToField(),
      nullifierHash,
      externalNullifier,
      proof
    );

    polls[uniquePollId] = Poll({
      owner: msg.sender,
      ended: false,
      question: question,
      choiceCount: choices.length
    });

    for (uint i = 0; i < choices.length; i++) { 
      choiceNames[uniquePollId][i] = choices[i];
      choiceVoteCounts[uniquePollId][i] = 0;
    }

    pollCount[msg.sender]++;
    totalPollCount++;

    return uniquePollId;
  }

  // End the poll. Noone can vote once the poll has ended
  function endPoll(
    uint256 id
  ) public {
    if (polls[id].owner != msg.sender) // Require wallot to be owner of the poll to end it.
      revert PollOwnerAuthentication();

    polls[id].ended = true;
  }

  // Verify the sender is a human and vote for a poll
  // "Because only people have an opinion"
  function verifyAndVote(
    uint256 id, // Id of the poll to vote for
    uint choice, // Index of the choice to vote for
    address signal, // An arbitrary input from the user, usually the user's wallet address (check README for further details)
    uint256 root, // The root of the Merkle tree (returned by the JS widget).
    uint256 nullifierHash, // The nullifier hash for this proof, preventing double signaling (returned by the JS widget).
    uint256[8] calldata proof // The zero-knowledge proof that demonstrates the claimer is registered with World ID (returned by the JS widget).
  ) public {
    if (polls[id].ended) // Poll is already ended
      revert PollIsEnded();
    if (hasVoted[id][nullifierHash]) // This voter has already voted
      revert AlreadyVoted();
    if (choice < polls[id].choiceCount) // Invalid choice
      revert ChoiceOutOfRange(polls[id].choiceCount);

    // Verify the provided proof is valid and the user is verified by World ID
    worldId.verifyProof(
      root,
      groupId,
      abi.encodePacked(signal).hashToField(),
      nullifierHash,
      externalNullifier,
      proof
    );

    hasVoted[id][nullifierHash] = true;
    choiceVoteCounts[id][choice]++;

    emit newVote(id, choiceNames[id][choice]);
  }
}