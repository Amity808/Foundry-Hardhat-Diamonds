// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/StakingFacet.sol";
import "../contracts/facets/StakingFacet.sol";
import "../contracts/facets/StakingFacetERC1155.sol";
import {AppStorage} from "../contracts/libraries/LibAppStorage.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import {IDiamondCut} from "../contracts/interfaces/IDiamondCut.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
// import "../contract/libraries/LibAppStorage.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
// import console
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract StakingFacetERC20Test is Test {
    Diamond diamond;
    StakingFacetERC20 stakingFacet;
    DiamondCutFacet diamondCutFacet;
    MockERC20 public token;
    address user = makeAddr("user");
    address erc20Token;
    address erc721Token;
    address erc1155Token;

    // MockERC20 public token;

    uint256 public constant DEFAULT_APR = 250;
    uint256 public constant DEFAULT_LOCK_DURATION = 1 days;
    uint256 public constant DEFAULT_APR_REDUCTION = 5;
    uint256 public constant DEFAULT_WITHDRAW_PENALTY = 50;
    uint256 public constant START_BALANCE = 100 ether;
    AppStorage internal s;

    function setUp() public {
        // Deploy Diamond and facets
        diamondCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(diamondCutFacet));
        stakingFacet = new StakingFacetERC20();
        token = new MockERC20();

        token.mint(user, 210);
        erc20Token = address(token); // Set erc20Token to the deployed token address
        erc721Token = address(token);
        erc1155Token = address(token);

        // ERC20Mock(erc20Token).mint(user, START_BALANCE);

        // Add StakingFacet to Diamond
        bytes4[] memory selectors = new bytes4[](12); //  selectors for the functions we're testing

        selectors[0] = StakingFacetERC20.stakeERC20.selector;
        selectors[1] = StakingFacetERC20.withdraw.selector;
        selectors[2] = StakingFacetERC20.claimRewards.selector;
        selectors[3] = StakingFacetERC20.getpendingRewards.selector;
        selectors[4] = StakingFacetERC20.initialize.selector;
        selectors[5] = StakingFacetERC20.getTestValue.selector;
        selectors[6] = StakingFacetERC20.getUserStakeDetails.selector;
        selectors[7] = StakingFacetERC20.getContractOwner.selector;
        selectors[8] = StakingFacetERC20.getMinLockDuratioLib.selector;
        selectors[9] = StakingFacetERC20.getStakingTokenLib.selector;
        selectors[10] = StakingFacetERC20.getInitialAprLib.selector;
        selectors[11] = StakingFacetERC20.getTimeUntilUnlockERC20.selector;

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);

        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(stakingFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

        // Initialize staking parameters - IMPORTANT:  Call the initializer via the DIAMOND
        StakingFacetERC20(address(diamond)).initialize(
            DEFAULT_APR,
            DEFAULT_APR_REDUCTION,
            erc20Token,
            erc721Token,
            DEFAULT_LOCK_DURATION,
            erc1155Token
        );
    }

    function testDeploy() public {
        // Check that the Diamond contract is deployed
        assertNotEq(address(diamond), address(0), "Diamond not deployed");

        // Check that the StakingFacet contract is deployed
        assertNotEq(
            address(stakingFacet),
            address(0),
            "StakingFacet not deployed"
        );

        // Check that the DiamondCutFacet contract is deployed
        assertNotEq(
            address(diamondCutFacet),
            address(0),
            "DiamondCutFacet not deployed"
        );

        // Check that the function selector is associated with the StakingFacet
        // assertTrue(
        //     diamond.supportsInterface(StakingFacetERC20.stakeERC20.selector),
        //     "Diamond does not support stakeERC20 selector"
        // );
        vm.prank(address(this));
        assertEq(
            StakingFacetERC20(address(diamond)).getTestValue(),
            123,
            "Diamond Cut Failed"
        );
    }

    function testStakeERC20() public {
        vm.startPrank(user);
        token.approve(address(diamond), 100);

        StakingFacetERC20(address(diamond)).stakeERC20(100);
        uint256 balance = token.balanceOf(user);
        console.log(balance, "balance");
        uint256 balance2 = token.balanceOf(address(diamond));
        console.log(balance2, "balance2");
        assertEq(
            token.balanceOf(address(diamond)),
            100,
            "Tokens not transferred to contract"
        );

        // Verify the user's stake
        // vm.prank(user);
        // console.log("user", StakingFacetERC20(address(diamond)).getUserStakeDetails(user));
        assertEq(
            StakingFacetERC20(address(diamond))
                .getUserStakeDetails(user)
                .stakedAmount,
            100,
            "Incorrect staked amount"
        );
        vm.stopPrank();
    }

    function testgetContractOwner() public {
        assertEq(
            StakingFacetERC20(address(diamond)).getContractOwner(),
            address(this),
            "Contract owner not set"
        );
    }

    function testGetMinLockDuratioLib() public {
        assertEq(
            StakingFacetERC20(address(diamond)).getMinLockDuratioLib(),
            DEFAULT_LOCK_DURATION
        );
    }

    // function testgetStakingToken() public {

    //     assertEq(
    //         StakingFacetERC20(address(diamond)).getUserStakeDetails(user).stakingToken,
    //         erc20Token
    //     );
    // }
    function testgetInitialAprLib() public {
        assertEq(
            StakingFacetERC20(address(diamond)).getInitialAprLib(),
            DEFAULT_APR
        );
    }

    function testWithdraw() public {
        // Setup test - first stake some tokens
        testStakeERC20();

        // Advance time to pass the lock duration
        vm.warp(block.timestamp + DEFAULT_LOCK_DURATION + 1);
        vm.roll(block.number + 1);

        //Prank call
        vm.prank(user);

        //Withdraw tokens
        StakingFacetERC20(address(diamond)).withdraw(100);

        //Verify user's balance
        assertEq(IERC20(erc20Token).balanceOf(user), 210, "Withdrawal failed");
    }

    function testGetTimeUntilUnlockERC20() public {
        // Stake some tokens
        vm.startPrank(user);
        token.approve(address(diamond), 100);
        StakingFacetERC20(address(diamond)).stakeERC20(100);
        vm.stopPrank();

        // Wait for a period less than the lock duration
        uint256 elapsedTime = DEFAULT_LOCK_DURATION / 2;
        vm.warp(block.timestamp + elapsedTime);
        vm.roll(block.number + 1);

        // Calculate the expected remaining time
        uint256 expectedRemainingTime = DEFAULT_LOCK_DURATION - elapsedTime;

        // Get the remaining time from the contract
        uint256 actualRemainingTime = StakingFacetERC20(address(diamond))
            .getTimeUntilUnlockERC20(user);

        // Assert that the remaining time is correct, allowing for a small tolerance
        int256 difference = int256(actualRemainingTime) -
            int256(expectedRemainingTime);
        assertTrue(difference <= 1, "Incorrect remaining time");
    }
}
