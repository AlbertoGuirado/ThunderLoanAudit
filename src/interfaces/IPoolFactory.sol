// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

// e interface to work with poolfactory.sol from tswap
interface IPoolFactory {
    function getPool(address tokenAddress) external view returns (address);
}
