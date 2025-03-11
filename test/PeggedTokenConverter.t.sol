//SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {PeggedTokenConverter} from "../src/PeggedTokenConverter.sol";
import {MockERC20} from "./utils/mocks/MockERC20.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract PeggedTokenConverterTest is Test {

    using Math for uint256;

    PeggedTokenConverter public converter;
    address implementation;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    address owner = address(12345);
    address emily = address(99999);
    address bob = address(88888);

    function setUp() public {
        tokenA = new MockERC20("Token A", "A", 6);
        tokenB = new MockERC20("Token B", "B", 6);

        implementation = address(new PeggedTokenConverter());
        address converterAddress = Clones.clone(implementation);
        converter = PeggedTokenConverter(converterAddress);
        converter.initialize(owner, address(tokenA), address(tokenB));

        tokenA.mint(owner, 100 ether);
        tokenB.mint(owner, 100 ether);
    }

    function test_setup() public view {
        assertEq(owner, converter.owner());
        assertEq(address(tokenA), address(converter.tokenA()));
        assertEq(address(tokenB), address(converter.tokenB()));
        assertEq(false, converter.bidirectional());
    }

    function testRevert_nonOwnerDeposit() public {
        tokenA.mint(emily, 10 ether);
        vm.startPrank(emily);
        tokenA.approve(address(converter), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), address(99999)));
        converter.deposit(address(tokenA), 1 ether);
    }

    function testRevert_invalidTokenDeposit() public {
        MockERC20 tokenC = new MockERC20("Token C", "C", 6);
        tokenC.mint(owner, 10 ether);
        vm.startPrank(owner);
        tokenC.approve(address(converter), 1 ether);
        vm.expectRevert("Invalid token type");
        converter.deposit(address(tokenC), 1 ether);
    }

    function testRevert_noZeroDeposit() public {
        uint256 amount = 10 ether;
        vm.startPrank(owner);
        tokenA.approve(address(converter), amount);

        vm.expectRevert("No zero deposit");
        converter.deposit(address(tokenA), 0);
    }

    function test_deposit() public {
        uint256 amount = 10 ether;
        vm.startPrank(owner);
        tokenA.approve(address(converter), amount);

        uint256 contractPreBalance = tokenA.balanceOf(address(converter));
        uint256 ownerPreBalance = tokenA.balanceOf(owner);

        converter.deposit(address(tokenA), amount);

        uint256 contractPostBalance = tokenA.balanceOf(address(converter));
        uint256 ownerPostBalance = tokenA.balanceOf(owner);
        assertEq(ownerPreBalance-amount, ownerPostBalance);
        assertEq(contractPreBalance+amount, contractPostBalance);
    }

    function test_depositMultipleTokens(uint256 amountA_, uint256 amountB_) public {
        vm.assume(amountA_ <= 100 ether);
        vm.assume(amountA_ > 0);
        vm.assume(amountB_ <= 100 ether);
        vm.assume(amountB_ > 0);

        tokenA.mint(owner, amountA_);
        tokenB.mint(owner, amountB_);
        vm.startPrank(owner);
        tokenA.approve(address(converter), amountA_);
        tokenB.approve(address(converter), amountB_);

        // Deposit token A
        converter.deposit(address(tokenA), amountA_);
        uint256 contractTokenABalance = tokenA.balanceOf(address(converter));
        assertEq(amountA_, contractTokenABalance);

        // Deposit token B
        converter.deposit(address(tokenB), amountB_);
        uint256 contractTokenBBalance = tokenB.balanceOf(address(converter));
        assertEq(amountB_, contractTokenBBalance);

        // Deposit token A again
        uint256 secondDepositAmt = 10 ether;
        tokenA.approve(address(converter), secondDepositAmt);
        converter.deposit(address(tokenA), secondDepositAmt);
        uint256 contractFinalTokenABalance = tokenA.balanceOf(address(converter));
        assertEq(amountA_+secondDepositAmt, contractFinalTokenABalance);
    }

    function testRevert_nonOwnerWithdrawal() public {
        vm.startPrank(emily);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), address(99999)));
        converter.withdraw(address(tokenA), 1 ether);
    }

    function testRevert_invalidTokenWithdrawal() public {
        MockERC20 tokenC = new MockERC20("Token C", "C", 6);
        tokenC.mint(owner, 10 ether);

        vm.startPrank(owner);
        vm.expectRevert("Invalid token type");
        converter.withdraw(address(tokenC), 1 ether);
    }

    function testRevert_noZeroWithdrawal() public {
        uint256 amount = 5 ether;
        vm.startPrank(owner);
        tokenA.approve(address(converter), amount);
        converter.deposit(address(tokenA), amount);

        vm.expectRevert("No zero withdraw");
        converter.withdraw(address(tokenA), 0);
    }

    function testRevert_insufficientFundsForWithdrawal() public {
        uint256 amount = 5 ether;
        vm.startPrank(owner);
        tokenA.approve(address(converter), amount);
        converter.deposit(address(tokenA), amount);

        uint256 contractBalance = tokenA.balanceOf(address(converter));
        vm.expectRevert("Insufficient contract balance");
        converter.withdraw(address(tokenA), contractBalance+1);
    }

    function test_withdraw() public {
        uint256 amount = 5 ether;
        vm.startPrank(owner);
        tokenA.approve(address(converter), amount);
        converter.deposit(address(tokenA), amount);

        uint256 contractBalance = tokenA.balanceOf(address(converter));
        assertEq(amount, contractBalance);

        uint256 ownerBalancePreWithdraw = tokenA.balanceOf(owner);

        converter.withdraw(address(tokenA), amount);

        uint256 ownerBalancePostWithdraw = tokenA.balanceOf(owner);
        uint256 contractBalancePostWithdraw = tokenA.balanceOf(address(converter));
        assertEq(ownerBalancePreWithdraw+amount, ownerBalancePostWithdraw);
        assertEq(contractBalance-amount, contractBalancePostWithdraw);
    }

    function testRevert_nonOwnerMaxWithdrawl() public {
        vm.startPrank(emily);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), address(99999)));
        converter.maxWithdraw(address(tokenA));
    }

    function testRevert_invalidTokenMaxWithdrawl() public {
        MockERC20 tokenC = new MockERC20("Token C", "C", 6);
        vm.startPrank(owner);
        vm.expectRevert("Invalid token type");
        converter.maxWithdraw(address(tokenC));
    }

    function test_maxWithdraw() public {
        uint256 amount = 10 ether;
        vm.startPrank(owner);
        tokenA.approve(address(converter), amount);
        converter.deposit(address(tokenA), amount);

        uint256 contractBalance = tokenA.balanceOf(address(converter));
        assertEq(amount, contractBalance);

        uint256 ownerBalancePreWithdraw = tokenA.balanceOf(owner);

        converter.maxWithdraw(address(tokenA));

        uint256 ownerBalancePostWithdraw = tokenA.balanceOf(owner);
        uint256 contractBalancePostWithdraw = tokenA.balanceOf(address(converter));
        assertEq(ownerBalancePreWithdraw+amount, ownerBalancePostWithdraw);
        assertEq(contractBalancePostWithdraw, 0);
    }

    function testRevert_nonOwnerToggleBidirectional() public {
        vm.startPrank(emily);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), address(99999)));
        converter.toggleBidirectional();
    }

    function test_toggleBidirectional() public {
        assertEq(converter.bidirectional(), false);

        // Toggle to true
        vm.startPrank(owner);
        converter.toggleBidirectional();
        assertEq(converter.bidirectional(), true);

        // Toggle back to false
        vm.startPrank(owner);
        converter.toggleBidirectional();
        assertEq(converter.bidirectional(), false);
    }

    function testRevert_convertInvalidToken() public {
        MockERC20 tokenC = new MockERC20("Token C", "C", 6);
        vm.startPrank(emily);
        vm.expectRevert("Invalid token type");
        converter.convert(address(tokenC), 10);
    }

    function testRevert_convertZeroAmount() public {
        vm.startPrank(emily);
        vm.expectRevert("No zero convert");
        converter.convert(address(tokenA), 0);
    }

    function testRevert_convertWhilePaused() public {
        vm.startPrank(emily);
        vm.expectRevert("Conversions paused");
        converter.convert(address(tokenB), 1);
    }

    function test_convertOverAvailableAmount() public {
        uint256 amount = 1000 ether;
        tokenA.mint(emily, amount);
        
        // Owner deposits liquidity
        uint256 depositAmount = 100 ether;
        vm.startPrank(owner);
        tokenB.approve(address(converter), depositAmount);
        converter.deposit(address(tokenB), depositAmount);

        vm.startPrank(emily);
        tokenA.approve(address(converter), amount);
        vm.expectRevert("Insufficient contract balance");
        converter.convert(address(tokenA), amount);
    }

    function test_convert() public {
        uint256 amount = 10 ether;
        tokenA.mint(emily, amount);
        
        // Owner deposits liquidity
        uint256 depositAmount = 100 ether;
        vm.startPrank(owner);
        tokenB.approve(address(converter), depositAmount);
        converter.deposit(address(tokenB), depositAmount);

        // Check contract balances pre-conversion
        uint256 contractTokenABalancePre = tokenA.balanceOf(address(converter));
        assertEq(contractTokenABalancePre, 0);
        uint256 contractTokenBBalancePre = tokenB.balanceOf(address(converter));
        assertEq(contractTokenBBalancePre, depositAmount);

        vm.startPrank(emily);
        tokenA.approve(address(converter), amount);
        converter.convert(address(tokenA), amount);

        // Check contract balances post-conversion
        uint256 contractTokenABalancePost = tokenA.balanceOf(address(converter));
        assertEq(contractTokenABalancePost, amount);
        uint256 contractTokenBBalancePost = tokenB.balanceOf(address(converter));
        assertEq(contractTokenBBalancePost, contractTokenBBalancePre-amount);

        // Check user balances
        uint256 userTokenABalance = tokenA.balanceOf(emily);
        assertEq(userTokenABalance, 0);
        uint256 userTokenBBalance = tokenB.balanceOf(emily);
        assertEq(userTokenBBalance, amount);
    }

    function test_convertBidirectional() public {
        uint256 amount = 10 ether;
        tokenB.mint(emily, amount);

        // Owner deposits liquidity for both token types
        uint256 depositAmount = 50 ether;
        vm.startPrank(owner);
        tokenA.approve(address(converter), depositAmount);
        converter.deposit(address(tokenA), depositAmount);
        tokenB.approve(address(converter), depositAmount);
        converter.deposit(address(tokenB), depositAmount);

        vm.startPrank(emily);
        tokenB.approve(address(converter), amount);
        // User's first conversion attempt fails as bidirectional bool is false
        vm.expectRevert("Conversions paused");
        converter.convert(address(tokenB), amount);
        vm.stopPrank();

        // Check contract balances pre-conversion
        uint256 contractTokenABalancePre = tokenA.balanceOf(address(converter));
        assertEq(contractTokenABalancePre, depositAmount);
        uint256 contractTokenBBalancePre = tokenB.balanceOf(address(converter));
        assertEq(contractTokenBBalancePre, depositAmount);

        // Owner enables bidirectional conversions
        vm.prank(owner);
        converter.toggleBidirectional();

        // User's second conversion attempt should be successful
        vm.startPrank(emily);
        converter.convert(address(tokenB), amount);

        // Check contract balances post-conversion
        uint256 contractTokenABalancePost = tokenA.balanceOf(address(converter));
        assertEq(contractTokenABalancePost, contractTokenABalancePre-amount);
        uint256 contractTokenBBalancePost = tokenB.balanceOf(address(converter));
        assertEq(contractTokenBBalancePost, contractTokenBBalancePre+amount);

        // Check user balances
        uint256 userTokenABalance = tokenA.balanceOf(emily);
        assertEq(userTokenABalance, amount);
        uint256 userTokenBBalance = tokenB.balanceOf(emily);
        assertEq(userTokenBBalance, 0);
    }
}
