// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;
import {AppStorage, LibAppStorage, Stake, ERC721Stake} from "../libraries/LibAppStorage.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import "../interfaces/IERC721.sol";
import "../interfaces/IERC1155.sol";
import "../libraries/LibEvent.sol";
import "../libraries/LibStaking.sol";
import "../libraries/LibUtils.sol";

contract StakingFacetERC20 {
    // AppStorage internal s;

    // constructor(
    //     uint256 _initialAPR,
    //     uint256 _aprReductionPerThousand,
    //     address _stakingToken,
    //     address _nftCollection,
    //     uint256 _minLockDuration,
    //     address _erc1155Token
    // ) payable {
    //     LibAppStorage.initialize(
    //         _initialAPR,
    //         _aprReductionPerThousand,
    //         _stakingToken,
    //         _nftCollection,
    //         _minLockDuration,
    //         _erc1155Token
    //     );

    //     LibAppStorage.setContractOwner(msg.sender);
    // }

    function initialize(
        uint256 _initialAPR,
        uint256 _aprReductionPerThousand,
        address _stakingToken,
        address _nftCollection,
        uint256 _minLockDuration,
        address _erc1155Token
    ) external {
        require(
            LibAppStorage.appStorage().contractOwner == address(0),
            "Already initialized"
        );
        LibAppStorage.initialize(
            _initialAPR,
            _aprReductionPerThousand,
            _stakingToken,
            _nftCollection,
            _minLockDuration,
            _erc1155Token
        );

        LibAppStorage.setContractOwner(msg.sender);
    }

    function stakeERC20(uint256 amount) external {
        AppStorage storage s = LibAppStorage.appStorage();
        require(amount > 0, "Cannot stake 0");
        s.stakingToken.transferFrom(msg.sender, address(this), amount);
        Stake storage user = s.erc20Stakes[msg.sender];
        user.stakedAmount += amount;
        user.timestamp = block.timestamp;

        _updateRewardRateERC20();
        s.totalERC20Staked += amount;

        emit LibEvent.Staked(
            msg.sender,
            amount,
            block.timestamp,
            s.totalERC20Staked,
            s.currentRewardRate
        );
    }

    // function stakeERC20(uint256 amount) external {
    //     AppStorage storage s = LibAppStorage.appStorage();
    //     require(amount > 0, "Cannot stake 0");

    //     // Transfer tokens to contract
    //     s.stakingToken.transferFrom(msg.sender, address(this), amount);

    //     // Fetch user stake
    //     Stake storage user = s.erc20Stakes[msg.sender];

    //     // Update pending rewards before modifying stake amount
    //     user.pendingRewards += _calculateRewards(msg.sender);

    //     // Update user staking data
    //     user.stakedAmount += amount;
    //     user.timestamp = block.timestamp;
    //     user.lastStakeTimestamp = block.timestamp;

    //     // Update total staked
    //     s.totalERC20Staked += amount;

    //     // Update reward rate
    //     _updateRewardRateERC20();

    //     emit LibEvent.Staked(
    //         msg.sender,
    //         amount,
    //         block.timestamp,
    //         s.totalERC20Staked,
    //         s.currentRewardRate
    //     );
    // }

    // Helper function to calculate rewards before staking
    function _calculateRewards(address user) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        Stake storage stake = s.erc20Stakes[user];

        if (stake.stakedAmount == 0) return 0;

        uint256 timeStaked = block.timestamp - stake.timestamp;
        return
            (stake.stakedAmount * s.currentRewardRate * timeStaked) /
            s.PRECISION;
    }

    // must be approve
    function stakeERC721(uint256 tokenId) external {
        AppStorage storage s = LibAppStorage.appStorage();
        require(
            s.erc721Stakes[msg.sender].timestamp == 0,
            "Token already staked"
        );

        s.nftCollection.safeTransferFrom(msg.sender, address(this), tokenId);

        s.erc721Stakes[msg.sender] = ERC721Stake({
            tokenId: tokenId,
            timestamp: block.timestamp,
            rewardDebt: 0,
            pendingRewards: 0,
            lastStakeTimestamp: block.timestamp,
            canWithdraw: false
        });

        LibUtils._updateRewardsERC721(msg.sender);

        emit LibEvent.StakedERC721(
            msg.sender,
            1,
            block.timestamp,
            s.totalERC20Staked,
            s.currentRewardRate
        );
    }

    function _updateRewards(address _user) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        Stake storage user = s.erc20Stakes[_user];

        if (user.stakedAmount == 0) {
            return;
        }

        uint256 timeElaped = block.timestamp - user.lastStakeTimestamp;
        uint256 minutesElapsed = timeElaped / 60;
        if (minutesElapsed > 0) {
            uint256 scalingFactor = 1e18;
            uint256 annualRate = (s.currentRewardRate * scalingFactor) / 100; // convert percent to decimal
            uint256 minutesPerYear = 365 days / 1 minutes;

            uint256 rewardPerMinute = (user.stakedAmount * annualRate) /
                (minutesPerYear * scalingFactor);
            uint256 newRewards = rewardPerMinute * minutesElapsed;

            user.pendingRewards += newRewards;
            user.lastStakeTimestamp = block.timestamp;
        }
    }

    function _updateRewardRateERC20() internal {
        AppStorage storage s = LibAppStorage.appStorage();
        uint256 initialApr = s.initialApr;
        uint256 newRate = initialApr;
        uint256 totalStaked = s.totalERC20Staked;
        uint256 currentRewardRate = s.currentRewardRate;
        // Avoid division by zero and ensure proper scaling
        if (totalStaked >= 1000 * 1e18) {
            uint256 scalingFactor = 1e18;
            uint256 thousandTokens = (totalStaked * scalingFactor) /
                (1000 * 1e18);
            uint256 aprReductionPerThousand = s.aprReductionPerThousand;
            uint256 reduction = (thousandTokens * aprReductionPerThousand) /
                scalingFactor;

            // Ensure we don't underflow when subtracting reduction
            newRate = reduction >= initialApr ? 10 : initialApr - reduction;
        }

        if (newRate != currentRewardRate) {
            uint256 oldRate = currentRewardRate;
            currentRewardRate = newRate;
            emit LibEvent.RewardRateUpdated(
                oldRate,
                newRate,
                block.timestamp,
                totalStaked
            );
        }
    }

    // erc 20 staked withdraw
    function withdraw(uint256 _amount) external {
        AppStorage storage s = LibAppStorage.appStorage();
        Stake storage user = s.erc20Stakes[msg.sender];
        require(_amount > 0, "Cannot withdraw 0");
        require(_amount <= user.stakedAmount, "Insufficient staked amount");
        require(
            block.timestamp >= user.lastStakeTimestamp + s.minLockDuration,
            "Lock duration not met"
        );

        // Update rewards before withdrawal
        LibUtils._updateRewardsERC721(msg.sender);

        // Update user info
        user.stakedAmount -= _amount;
        s.totalERC20Staked -= _amount;

        // Transfer tokens back to user
        require(
            s.stakingToken.transfer(msg.sender, _amount),
            "Transfer failed"
        );

        // Update reward rate
        _updateRewardRateERC20();

        emit LibEvent.Withdrawn(
            msg.sender,
            _amount,
            block.timestamp,
            s.totalERC20Staked,
            s.currentRewardRate,
            user.pendingRewards
        );
    }

    function claimRewards() external {
        AppStorage storage s = LibAppStorage.appStorage();
        _updateRewards(msg.sender);
        Stake storage user = s.erc20Stakes[msg.sender];

        uint256 rewards = user.pendingRewards;
        require(rewards > 0, "No rewards to claim");

        user.pendingRewards = 0;
        user.rewardDebt = 0;

        require(
            s.stakingToken.transfer(msg.sender, rewards),
            "Transfer failed"
        );

        emit LibEvent.RewardsClaimed(
            msg.sender,
            rewards,
            block.timestamp,
            user.pendingRewards,
            s.totalERC20Staked
        );
    }

    function withdrawERC721(uint256 _amount) external {
        AppStorage storage s = LibAppStorage.appStorage();
        ERC721Stake storage user = s.erc721Stakes[msg.sender];
        require(_amount > 0, "Cannot withdraw 0");
        require(_amount <= user.pendingRewards, "Insufficient staked amount");
        require(
            block.timestamp >= user.lastStakeTimestamp + s.minLockDuration,
            "Lock duration not met"
        );

        // Update rewards before withdrawal
        _updateRewards(msg.sender);

        // Update user info
        user.pendingRewards -= _amount;
        s.totalERC20Staked -= _amount;

        // Transfer tokens back to user
        require(
            s.stakingToken.transfer(msg.sender, _amount),
            "Transfer failed"
        );

        // Update reward rate
        _updateRewardRateERC20();

        emit LibEvent.Withdrawn(
            msg.sender,
            _amount,
            block.timestamp,
            s.totalERC20Staked,
            s.currentRewardRate,
            user.pendingRewards
        );
    }

    function getpendingRewards(address user) external view returns (uint256) {
        return LibStaking.getPendingRewardsERC20(user);
    }

    function getTimeUntilUnlockERC20(
        address user
    ) external view returns (uint256) {
        return LibStaking.getTimeUntilUnlockERC20(user);
    }

    function getUserStakeDetails(
        address _user
    ) external view returns (Stake memory) {
        return LibStaking.getUserDetails(_user);
    }

    function getTotalRewards() external view returns (uint256) {
        return LibStaking.getTotalRewards();
    }

    function getTestValue() external pure returns (uint256) {
        return 123;
    }

    function getContractOwner() external view returns (address) {
        return LibAppStorage.appStorage().contractOwner;
    }

    function getMinLockDuratioLib() external view returns (uint256) {
        return LibAppStorage.getMinLockDuration();
    }

    function getStakingTokenLib() external view returns (IERC20) {
        return LibAppStorage.getStakingToken();
    }
    
    function getInitialAprLib() external view returns (uint256) {
        return LibAppStorage.getInitialApr();
    }
}
