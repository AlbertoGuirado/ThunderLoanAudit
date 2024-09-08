// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

import { ITSwapPool } from "../interfaces/ITSwapPool.sol";
import { IPoolFactory } from "../interfaces/IPoolFactory.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract OracleUpgradeable is Initializable {
    address private s_poolFactory;

    // Can't have constructor
    // Storage -> proxy
    // logic -> implementatioin -> constructor


    function __Oracle_init(address poolFactoryAddress) internal onlyInitializing {
        //@ audit need to do zero address checks
        __Oracle_init_unchained(poolFactoryAddress);
    }

    function __Oracle_init_unchained(address poolFactoryAddress) internal onlyInitializing {
        //@ audit need to do zero address checks
        s_poolFactory = poolFactoryAddress;
    }

    // e qe are calling an external contract
    // what if the price is manipulated? Can I? - reentrancy?
    function getPriceInWeth(address token) public view returns (uint256) {
        address swapPoolOfToken = IPoolFactory(s_poolFactory).getPool(token);
        // e ignoring token decimals
        // q what if the token has 6 decimals, is the price wrong?
        // contract weirdToken is ERC20
        return ITSwapPool(swapPoolOfToken).getPriceOfOnePoolTokenInWeth();
    }

    function getPrice(address token) external view returns (uint256) {
        return getPriceInWeth(token);
    }

    function getPoolFactoryAddress() external view returns (address) {
        return s_poolFactory;
    }
}
