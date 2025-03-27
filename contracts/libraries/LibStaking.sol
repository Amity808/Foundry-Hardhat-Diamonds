// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;
import {AppStorage, LibAppStorage, Stake} from "../libraries/LibAppStorage.sol";

library LibStaking {
    function getPendingRewardsERC20(
        address _user
    ) public view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();

        Stake storage user = s.erc20Stakes[_user];
        if (user.stakedAmount == 0) {
            return user.pendingRewards;
        }

        uint256 timeElapsed = block.timestamp - user.lastStakeTimestamp;
        uint256 minutesElapsed = timeElapsed / 60;

        if (minutesElapsed > 0) {
            // Use same scaling factor logic as _updateRewards
            uint256 scalingFactor = 1e18;
            uint256 annualRate = (s.currentRewardRate * scalingFactor) / 100;
            uint256 minutesPerYear = 365 days / 1 minutes;

            uint256 rewardPerMinute = (user.stakedAmount * annualRate) /
                (minutesPerYear * scalingFactor);
            uint256 newRewards = rewardPerMinute * minutesElapsed;

            return user.pendingRewards + newRewards;
        }

        return user.pendingRewards;
    }

    function getTimeUntilUnlockERC20(
        address _user
    ) external view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        Stake storage user = s.erc20Stakes[_user];
        uint256 minLockDuration = s.minLockDuration;
        if (block.timestamp >= user.lastStakeTimestamp + minLockDuration) {
            return 0;
        }
        return user.lastStakeTimestamp + minLockDuration - block.timestamp;
    }

    function getUserDetails(
        address _user
    ) external view returns (Stake memory) {
        AppStorage storage s = LibAppStorage.appStorage();
        Stake storage user = s.erc20Stakes[_user];
        uint256 minLockDuration = s.minLockDuration;
        uint256 timeUntilUnlock = block.timestamp >=
            user.lastStakeTimestamp + minLockDuration
            ? 0
            : user.lastStakeTimestamp + minLockDuration - block.timestamp;

        return
            Stake({
                stakedAmount: user.stakedAmount,
                timestamp: user.lastStakeTimestamp,
                tokenId: user.tokenId,
                rewardDebt: user.rewardDebt,
                pendingRewards: getPendingRewardsERC20(_user),
                lastStakeTimestamp: timeUntilUnlock,
                canWithdraw: block.timestamp >=
                    user.lastStakeTimestamp + minLockDuration
            });
    }

    function getTotalRewards() external view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();

        uint256 contractBalance = s.stakingToken.balanceOf(address(this));
        uint256 totalStaked = s.totalERC20Staked;
        // Ensure we don't underflow
        require(
            contractBalance >= totalStaked,
            "Invalid state: balance < staked"
        );
        return contractBalance - totalStaked;
    }
}
