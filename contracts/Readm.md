// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
*
* Implementation of a diamond.
/******************************************************************************/

import {LibDiamond} from "./libraries/LibDiamond.sol";
import {IDiamondCut} from "./interfaces/IDiamondCut.sol";
import { LibAppStorage } from "../interfaces/LibAppStorage.sol";
contract Diamond {
    constructor(address _contractOwner, address _diamondCutFacet) payable {
        LibDiamond.setContractOwner(_contractOwner);

        // Add the diamondCut external function from the diamondCutFacet
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IDiamondCut.diamondCut.selector;
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: _diamondCutFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
        LibDiamond.diamondCut(cut, address(0), "");
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        // get diamond storage
        assembly {
            ds.slot := position
        }
        // get facet from function selector
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        require(facet != address(0), "Diamond: Function does not exist");
        // Execute external function from facet using delegatecall and return any value.
        assembly {
            // copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            // execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            // get any return value
            returndatacopy(0, 0, returndatasize())
            // return any return value or error back to the caller
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    //immutable function example
    function example() public pure returns (string memory) {
        return "THIS IS AN EXAMPLE OF AN IMMUTABLE FUNCTION";
    }

    receive() external payable {}
}



    MockERC20 public token;

    uint256 public constant DEFAULT_APR = 250;
    uint256 public constant DEFAULT_LOCK_DURATION = 1 days;
    uint256 public constant DEFAULT_APR_REDUCTION = 5;
    uint256 public constant DEFAULT_WITHDRAW_PENALTY = 50;

    function testDeployDiamond() public {
        // uint256 _initialAPR,
        // uint256 _aprReductionPerThousand,
        // address _stakingToken,
        // address _nftCollection,
        // uint256 _minLockDuration,
        // address _erc1155Token,
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(
            DEFAULT_APR,
            DEFAULT_APR_REDUCTION,
            address(token),
            address(token),
            DEFAULT_LOCK_DURATION,
            address(token),
            address(dCutFacet)
        );



import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
// import "../contracts/facets/DiamondLoupeFacet.sol";
// import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/StakingFacet.sol";
import "../contracts/facets/StakingFacetERC1155.sol";
import "./helpers/DiamondUtils.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {Stake} from "../contracts/libraries/LibAppStorage.sol";