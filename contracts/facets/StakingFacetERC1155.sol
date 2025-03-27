// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;
import {AppStorage, LibAppStorage, Stake, ERC1155Stake} from "../libraries/LibAppStorage.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import "../interfaces/IERC721.sol";
import "../interfaces/IERC1155.sol";
import "../libraries/LibEvent.sol";
import "../libraries/LibStaking.sol";
// import "../libraries/LibUtils.sol";

contract StakingFacetERC1155 {
    // AppStorage internal s;

    function stakeERC1155(uint256 amount, uint256 tokenId) external {
        AppStorage storage s = LibAppStorage.appStorage();
        require(amount > 0, "Cannot stake 0");
        s.erc1155Token.safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            amount,
            ""
        );
        ERC1155Stake storage user = s.erc1155Stakes[msg.sender][tokenId];
        user.stakedAmount += amount;
        user.tokenId = tokenId;
        user.timestamp += block.timestamp;
        _updateRewardRateERC1155();
        s.totalERC1155Staked += amount;

        emit LibEvent.Staked(
            msg.sender,
            amount,
            block.timestamp,
            s.totalERC1155Staked,
            s.currentRewardRate
        );
    }

    function _updateRewardRateERC1155() internal {
        AppStorage storage s = LibAppStorage.appStorage();
        uint256 initialApr = s.initialApr;
        uint256 newRate = initialApr;
        uint256 totalStaked = s.totalERC1155Staked;
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
    function _updateRewards(uint256 _tokenId) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        ERC1155Stake storage user = s.erc1155Stakes[msg.sender][_tokenId];

        if (user.stakedAmount == 0 || user.tokenId != _tokenId) {
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

    function unstake(uint256 _tokenId, uint256 _amount) external {
        AppStorage storage s = LibAppStorage.appStorage();
        ERC1155Stake storage user = s.erc1155Stakes[msg.sender][_tokenId];
        require(
            s.erc1155Stakes[msg.sender][_tokenId].stakedAmount > 0,
            "Nothing staked"
        );
        require(user.tokenId == _tokenId, "Invalid tokenId");
        require(
            block.timestamp >= user.lastStakeTimestamp + s.minLockDuration,
            "Lock duration not met"
        );
        _updateRewards(_tokenId);
        user.stakedAmount -= _amount;
        s.totalERC1155Staked -= _amount;

        s.erc1155Token.safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId,
            _amount,
            "0x"
        );
        emit LibEvent.Withdrawn(
            msg.sender,
            _amount,
            block.timestamp,
            s.totalERC1155Staked,
            s.currentRewardRate,
            user.pendingRewards
        );
        if (user.stakedAmount == 0) {
            delete s.erc1155Stakes[msg.sender][_tokenId];
        }
    }
}
