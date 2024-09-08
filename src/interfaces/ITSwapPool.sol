// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

// qanswered Why are we only using the price of a pool token in weth
// a we shouldnt be , this is a bug 
interface ITSwapPool {
    function getPriceOfOnePoolTokenInWeth() external view returns (uint256);
}
