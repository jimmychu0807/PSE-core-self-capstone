// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IGuessingGame {
  struct Bid {
    bytes32 bid_null_hash;
    bytes32 null_hash;
  }

  struct Game {
    // game players. The first player is the game host
    address[] players;
    mapping(address => uint8[]) winning;
    uint8 currentRound;
    GameState state;
    // player bid list
    mapping(uint8 => mapping(address => Bid)) bids;
    mapping(uint8 => mapping(address => uint8)) revelations;
    address finalWinner;
    uint256 startTime;
    uint256 lastUpdate;
    uint256 endTime;
  }

  // game state
  enum GameState {
    GameInitiated,
    RoundBid,
    RoundReveal,
    RoundEnd,
    GameEnd
  }

  // Error declaration
  error GuessingGame__InvalidGameId();
  error GuessingGame__GameHasEnded();
  error GuessingGame__UnexpectedGameState(GameState actual);
  error GuessingGame__PlayerAlreadyJoin(address p);
  error GuessingGame__SenderIsNotGameHost();
  error GuessingGame__SenderNotOneOfPlayers();
  error GuessingGame__BidProofRejected(address, uint32, uint8);
  error GuessingGame__BidOutOfRange(address, uint8);

  // Emitted Events
  event NewGame(uint32 indexed gameId, address indexed sender);
  event PlayerJoinGame(uint32 indexed gameId, address indexed sender);
  event GameStarted(uint32 gameId);
  event GameStateUpdated(uint32 gameId, GameState state);
  event BidSubmitted(uint32 gameId, uint8 round, address sender);
  event BidRevealed(uint32 gameId, uint8 round, address sender);

  // External Functions
  function newGame() external returns (uint32 gameId);
  function joinGame(uint32 gameId) external;
  function startRound(uint32 gameId) external;
  function submitBid(uint32 gameId, bytes32 bid_nullifier_hash, bytes32 nullifier_hash) external;
  function revealBid(uint32 gameId, bytes32 proof, uint8 bid, uint256 nullifier) external;
}
