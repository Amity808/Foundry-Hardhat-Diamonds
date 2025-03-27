// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import "../interfaces/IERC721.sol";
import "../interfaces/IERC1155.sol";

struct AppStorage1 {
    uint256 secondVar;
    uint256 firstVar;
    uint256 lastVar;
    // add other state variables ...
}

// user stake
struct Stake {
    uint256 stakedAmount;
    uint256 timestamp;
    uint256 tokenId;
    uint256 rewardDebt;
    uint256 pendingRewards;
    uint256 lastStakeTimestamp;
    bool canWithdraw;
}

struct ERC721Stake {
    uint256 tokenId;
    uint256 timestamp;
    uint256 rewardDebt;
    uint256 pendingRewards;
    uint256 lastStakeTimestamp;
    bool canWithdraw;
}
struct ERC1155Stake {
    uint256 stakedAmount;
    uint256 tokenId;
    uint256 timestamp;
    uint256 rewardDebt;
    uint256 pendingRewards;
    uint256 lastStakeTimestamp;
    bool canWithdraw;
}

struct AppStorage {
    // ERC20 staking
    mapping(address => Stake) erc20Stakes; // user token
    uint256 totalERC20Staked; // totalStaked
    // ERC721 staking
    mapping(address => ERC721Stake) erc721Stakes;
    // ERC1155 staking
    mapping(address => mapping(uint256 => ERC1155Stake)) erc1155Stakes; // user => token => tokenId => Stake
    uint256 totalERC1155Staked;
    uint256 initialApr;
    uint256 minLockDuration;
    uint256 aprReductionPerThousand;
    uint256 emergencyWithdrawPenalty;
    uint256 REWARDS_PER_MINUTE_PRECISION;
    uint256 PRECISION;
    uint256 currentRewardRate;
    IERC20 stakingToken;
    IERC721 nftCollection;
    IERC1155 erc1155Token;
    address contractOwner;
}

// 2. In a facet that imports the AppStorage struct declare an AppStorage state variable called `s`.
//    This should be the only state variable declared in the facet.

// 3. In your facet you can now access all the state variables in AppStorage by prepending state variables
//    with `s.`. Here is example code:

// import { AppStorage } from "./LibAppStorage.sol";

// contract AFacet {
//     AppStorage internal s;

//     function sumVariables() external {
//         s.lastVar = s.firstVar + s.secondVar;
//     }

//     function getFirsVar() external view returns (uint256) {
//         return s.firstVar;
//     }

//     function setLastVar(uint256 _newValue) external {
//         s.lastVar = _newValue;
//     }
// }

// Sharing AppStorage in another facet:

// import { AppStorage } from "./LibAppStorage.sol";

// contract SomeOtherFacet {
//     AppStorage internal s;

//     function getLargerVar() external view returns (uint256) {
//         uint256 firstVar = s.firstVar;
//         uint256 secondVar = s.secondVar;
//         if(firstVar > secondVar) {
//             return firstVar;
//         }
//         else {
//             return secondVar;
//         }
//     }
// }

// Using the 's.' prefix to access AppStorage is a nice convention because it makes state variables
// concise, easy to access, and it distinguishes state variables from local variables and prevents
// name clashes/shadowing with local variables and function names. It helps identify and make
// explicit state variables in a convenient and concise way. AppStorage can be used in regular
// contracts as well as proxy contracts, diamonds, implementation contracts, Solidity libraries and
// facets.

// Since `AppStorage s` is the first and only state variable declared in facets its position in
// contract storage is `0`. This fact can be used to access AppStorage in Solidity libraries using
// diamond storage access. Here's an example of that:

library LibAppStorage {
    function appStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }

    // function someFunction() internal {
    //     AppStorage storage s = appStorage();
    //     s.firstVar = 8;
    //     //... do more stuff
    // }
    function abs(int256 x) internal pure returns (uint256) {
        return uint256(x >= 0 ? x : -x);
    }
    function initialize(
        uint256 _initialAPR,
        uint256 _aprReductionPerThousand,
        address _stakingToken,
        address _nftCollection,
        uint256 _minLockDuration,
        address _erc1155Token
    ) internal {
        AppStorage storage s = appStorage();
        require(_initialAPR > 0, "Invalid APR");
        s.minLockDuration = _minLockDuration;
        s.aprReductionPerThousand = _aprReductionPerThousand;
        s.REWARDS_PER_MINUTE_PRECISION = 1e18;
        s.PRECISION = 1e18;
        s.stakingToken = IERC20(_stakingToken);
        s.nftCollection = IERC721(_nftCollection);
        s.currentRewardRate = _initialAPR;
        s.erc1155Token = IERC1155(_erc1155Token);
    }
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    function setContractOwner(address _newOwner) internal {
        AppStorage storage s = appStorage();
        address previousOwner = s.contractOwner;
        s.contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function getContractOwner() internal view returns (address) {
        return appStorage().contractOwner;
    }

    function getStakingToken() internal view returns (IERC20) {
        return appStorage().stakingToken;
    }

    function getNftCollection() internal view returns (IERC721) {
        return appStorage().nftCollection;
    }

    function getErc1155Token() internal view returns (IERC1155) {
        return appStorage().erc1155Token;
    }

    function getInitialApr() internal view returns (uint256) {
        return appStorage().initialApr;
    }

    function getMinLockDuration() internal view returns (uint256) {
        return appStorage().minLockDuration;
    }
}

// `AppStorage s` can be declared as the one and only state variable in facets or it can be declared in a
// contract that facets inherit.

// AppStorage won't work if state variables are declared outside of AppStorage and outside of Diamond Storage.
// It is a common error for a facet to inherit a contract that declares state variables outside AppStorage and
// Diamond Storage. This causes a misalignment of state variables.

// One downside is that state variables can't be declared public in structs so getter functions can't
// automatically be created this way. But it can be nice to make your own getter functions for
// state variables because it is explicit.

// The rules for upgrading AppStorage are the same for Diamond Storage. These rules can be found at
// the end of the file ./DiamondStorage.sol
