// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;
import "../libraries/LibAppStorage.sol";
import "../libraries/LibEvent.sol";

library LibUtils {
    function _updateRewardsERC721(address _user) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        ERC721Stake storage user = s.erc721Stakes[_user];

        if (user.timestamp == 0) {
            return;
        }

        uint256 timeElaped = block.timestamp - user.lastStakeTimestamp;
        uint256 minutesElapsed = timeElaped / 60;
        if (minutesElapsed > 0) {
            uint256 scalingFactor = 1e18;
            uint256 annualRate = (s.currentRewardRate * scalingFactor) / 100; // convert percent to decimal
            uint256 minutesPerYear = 365 days / 1 minutes;

            uint256 rewardPerMinute = (1 * annualRate) /
                (minutesPerYear * scalingFactor);
            uint256 newRewards = rewardPerMinute * minutesElapsed;

            user.pendingRewards += newRewards;
            user.lastStakeTimestamp = block.timestamp;
        }
    }

    function _updateRewardRateERC721() internal {
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
}
