// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {BaseTest} from "../lib/contracts/test/BaseTest.sol";
import {BondingCurveToken} from "../src/BondingCurveToken.sol";

contract BondingCurveTokenTest is BaseTest {
    BondingCurveToken public bondingCurveToken;

    function _setUp() public override {
        bondingCurveToken = new BondingCurveToken("Bonding Curve Token", "BCT", 1_000_000_000 * 1e18);
    }

    function testCalculatePurchaseAmount() public {
        uint256 tokensToMint1Ether = bondingCurveToken.calculatePurchaseAmount(1 ether, 0);
        assertEq(tokensToMint1Ether, 357770876399966351425467786);

        uint256 tokensToMint2Ether = bondingCurveToken.calculatePurchaseAmount(2 ether, 0);
        assertEq(tokensToMint2Ether, 505964425626940693119822967);    

        uint256 tokensToMint3Ether = bondingCurveToken.calculatePurchaseAmount(3 ether, 0); 
        assertEq(tokensToMint3Ether, 619677335393186701628682463);

        uint256 tokensToMint4Ether = bondingCurveToken.calculatePurchaseAmount(4 ether, 0);
        assertEq(tokensToMint4Ether, 715541752799932702850935573);

        uint256 tokensToMint5Ether = bondingCurveToken.calculatePurchaseAmount(5 ether, 0);
        assertEq(tokensToMint5Ether, 800000000000000000000000000);        
    }


}