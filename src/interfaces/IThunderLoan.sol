// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// @ audit INFO should be implemented by the ThunderLoad contract
interface IThunderLoan {
    // @ audit LOW/INFO The function is should be IERC20
    function repay(address token, uint256 amount) external;
}
