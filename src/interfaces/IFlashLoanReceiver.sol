// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.20;

// @audit info Unused import
import { IThunderLoan } from "./IThunderLoan.sol";

/**
 * @dev Inspired by Aave:
 * https://github.com/aave/aave-v3-core/blob/master/contracts/flashloan/interfaces/IFlashLoanReceiver.sol
 */
interface IFlashLoanReceiver {
    // qanswered is the token, the token thats being borrowed
    // a yes
    // @audit natspec
    // qanswered amount of tokens?
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata params
    )
        external
        returns (bool);
}
