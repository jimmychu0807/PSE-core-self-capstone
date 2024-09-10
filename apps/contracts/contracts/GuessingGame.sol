// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IGuessingGame} from "./interfaces/IGuessingGame.sol";
import {ISubmitRangeCheckVerifier} from "./interfaces/ISubmitRangeCheckVerifier.sol";
import {MIN_NUM, MAX_NUM, ROUND_TO_WIN} from "./base/Constants.sol";

contract GuessingGame is IGuessingGame, Ownable {
  ISubmitRangeCheckVerifier public submitRangeCheckVerifier;

  // Storing all the game info. Refer to the interface to see the game struct
  Game[] public games;
  uint32 public nextGameId = 0;

  // Constructor
  // @param srAddr: submit-rangecheck verifier address
  constructor(ISubmitRangeCheckVerifier srAddr) Ownable(msg.sender) {
    // Initialization happens here
    submitRangeCheckVerifier = srAddr;
  }

  // Modifiers declaration
  modifier validGameId(uint32 gameId) {
    if (gameId >= nextGameId) {
      revert GuessingGame__InvalidGameId();
    }
    _;
  }

  modifier nonEndState(uint32 gameId) {
    Game storage game = games[gameId];
    if (game.state == GameState.GameEnd) {
      revert GuessingGame__GameHasEnded();
    }
    _;
  }

  modifier oneOfPlayers(uint32 gameId) {
    Game storage game = games[gameId];
    bool found = false;
    for (uint8 i = 0; i < game.players.length; ++i) {
      if (game.players[i] == msg.sender) {
        found = true;
        break;
      }
    }
    if (!found) {
      revert GuessingGame__NotOneOfPlayers();
    }
    _;
  }

  modifier gameStateEq(uint32 gameId, GameState gs) {
    Game storage game = games[gameId];
    if (game.state != gs) {
      revert GuessingGame__UnexpectedGameState(gs, game.state);
    }
    _;
  }

  modifier byGameHost(uint32 gameId) {
    Game storage game = games[gameId];
    address host = game.players[0];
    if (host != msg.sender) {
      revert GuessingGame__NotGameHost(gameId, msg.sender);
    }
    _;
  }

  /**
   * View functions
   **/

  function getGame(uint32 gameId) public view validGameId(gameId) returns (GameView memory) {
    Game storage game = games[gameId];

    return
      GameView({
        players: game.players,
        roundWinners: game.roundWinners,
        currentRound: game.currentRound,
        state: game.state,
        finalWinner: game.finalWinner,
        startTime: game.startTime,
        lastUpdate: game.lastUpdate,
        endTime: game.endTime
      });
  }

  function getPlayerCommitment(
    uint32 gameId,
    uint8 round,
    address player
  ) public view validGameId(gameId) returns (Bid memory) {
    Game storage game = games[gameId];

    return game.bids[round][player];
  }

  function getGameHost(uint32 gameId) public view validGameId(gameId) returns (address) {
    Game storage game = games[gameId];
    return game.players[0];
  }

  function _updateGameState(
    uint32 gameId,
    GameState state
  ) internal validGameId(gameId) nonEndState(gameId) {
    Game storage game = games[gameId];
    game.state = state;

    // Dealing with time recording
    game.lastUpdate = block.timestamp;
    if (state == GameState.GameInitiated) {
      game.startTime = game.lastUpdate;
    } else if (state == GameState.GameEnd) {
      game.endTime = game.lastUpdate;
    }

    emit GameStateUpdated(gameId, state);
  }

  function _countWinningRound(
    uint32 gameId,
    address roundWinner
  ) internal view returns (uint8 cnt) {
    Game storage game = games[gameId];
    cnt = 0;

    for (uint8 i = 0; i < game.roundWinners.length; ++i) {
      if (game.roundWinners[i] == roundWinner) {
        ++cnt;
      }
    }
  }

  /**
   * Main functions
   **/

  function newGame() external override returns (uint32 gameId) {
    Game storage game = games.push();
    game.players.push(msg.sender);
    gameId = nextGameId++;
    _updateGameState(gameId, GameState.GameInitiated);

    emit NewGame(gameId, msg.sender);
  }

  function joinGame(
    uint32 gameId
  ) external override validGameId(gameId) gameStateEq(gameId, GameState.GameInitiated) {
    Game storage game = games[gameId];
    // check the player has not been added to the game
    for (uint8 i = 0; i < game.players.length; ++i) {
      if (game.players[i] == msg.sender) {
        revert GuessingGame__PlayerAlreadyJoin(msg.sender);
      }
    }

    game.players.push(msg.sender);
    emit PlayerJoinGame(gameId, msg.sender);
  }

  function startGame(
    uint32 gameId
  )
    external
    override
    validGameId(gameId)
    byGameHost(gameId)
    gameStateEq(gameId, GameState.GameInitiated)
  {
    Game storage game = games[gameId];
    // Need at least three players for a game
    // 1 player: no game
    // 2 players: both player tie
    if (game.players.length <= 2) {
      revert GuessingGame__NotEnoughPlayers(gameId);
    }

    _updateGameState(gameId, GameState.RoundBid);
    emit GameStarted(gameId);
  }

  function submitCommitment(
    uint32 gameId,
    uint256[24] calldata proof,
    uint256[2] calldata pubSignals
  )
    external
    override
    validGameId(gameId)
    oneOfPlayers(gameId)
    gameStateEq(gameId, GameState.RoundBid)
  {
    // each player submit a bid. The last player that submit a bid will change the game state
    Game storage game = games[gameId];
    uint8 round = game.currentRound;

    // Verify the computation and proof
    if (!submitRangeCheckVerifier.verifyProof(proof, pubSignals)) {
      revert GuessingGame__InvalidSubmitRangeCheckProof(gameId, round, msg.sender);
    }

    game.bids[round][msg.sender] = Bid(pubSignals[0], pubSignals[1]);
    emit BidSubmitted(gameId, round, msg.sender);

    // If all players have submitted bid, update game state
    bool notYetBid = false;
    for (uint i = 0; i < game.players.length; ++i) {
      address p = game.players[i];
      if (game.bids[round][p].nullifier == 0) {
        notYetBid = true;
        break;
      }
    }

    if (!notYetBid) {
      _updateGameState(gameId, GameState.RoundReveal);
    }
  }

  function openCommitment(
    uint32 gameId,
    bytes32 proof,
    uint16 bid
  )
    external
    override
    validGameId(gameId)
    oneOfPlayers(gameId)
    gameStateEq(gameId, GameState.RoundReveal)
  {
    Game storage game = games[gameId];

    // each player reveal a bid. The last player that reveal a bid will change the game state

    uint8 round = game.currentRound;
    game.revelations[round][msg.sender] = bid;
    emit BidRevealed(gameId, round, msg.sender);

    // If all players have submitted revelation, update game state
    bool notYetReveal = false;
    for (uint i = 0; i < game.players.length; ++i) {
      address p = game.players[i];
      if (game.revelations[round][p] == 0) {
        notYetReveal = true;
        break;
      }
    }

    if (!notYetReveal) {
      _updateGameState(gameId, GameState.RoundEnd);
    }
  }

  function endRound(
    uint32 gameId
  )
    external
    override
    validGameId(gameId)
    byGameHost(gameId)
    gameStateEq(gameId, GameState.RoundEnd)
  {
    Game storage game = games[gameId];

    /**
     * TODO: calc the average of all bids, determine the winnder
     **/

    // Assume the game host is winner for now
    address roundWinner = game.players[0];

    // Notice we also update the game.currentRound here
    uint8 round = game.currentRound++;
    game.roundWinners.push(roundWinner);

    // update the game.state or end the game
    if (_countWinningRound(gameId, roundWinner) == ROUND_TO_WIN) {
      game.finalWinner = roundWinner;
      emit GameWinner(gameId, roundWinner);
      _updateGameState(gameId, GameState.GameEnd);
    } else {
      emit RoundWinner(gameId, round, roundWinner);
      _updateGameState(gameId, GameState.RoundBid);
    }
  }
}
