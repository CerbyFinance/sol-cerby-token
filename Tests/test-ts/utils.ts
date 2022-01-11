import { CerbySwapV1Instance } from "../types/truffle-contracts";

type CS = CerbySwapV1Instance;

export function getCurrentFeeBasedOnTrades(cs: CS, input: string | number) {
  if (typeof input === "string") {
    return cs.methods["getCurrentFeeBasedOnTrades(address)"](input);
  }

  return cs.methods["getCurrentFeeBasedOnTrades(uint256)"](input);
}