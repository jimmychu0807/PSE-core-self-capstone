// TODO: how do you package and deploy the contract artifact from hardhat package?
//   L NX> check how dark forest handle this.
import * as GameJSON from "../../contracts/artifacts/contracts/GuessingGame.sol/GuessingGame.json";
import { deployedAddress } from "./consts";

// IMPROVE: can you get this GameState from hardhat compilation?
export enum GameState {
  GameInitiated = 0,
  RoundCommit,
  RoundOpen,
  RoundEnd,
  GameEnd,
}

export const MIN_PLAYERS_TO_START = 3;

export const gameEventTypes = {
  newGame: "NewGame",
} as const;

export const gameArtifact = {
  ...GameJSON,
  // Added a new property of the deployed address.
  // Since we used CREATE2 to deploy contract (https://hardhat.org/ignition/docs/guides/create2),
  //   the deployed address should be the same across all chains.
  deployedAddress,
} as const;
