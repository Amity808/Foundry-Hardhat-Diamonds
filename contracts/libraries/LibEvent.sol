// SPDX-License-Identifier: Apache

pragma solidity 0.8.20;

library LibEvent {
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Staked(
        address indexed user,
        uint256 amount,
        uint256 timestamp,
        uint256 newTotalStaked,
        uint256 currentRewardRate
    );

    event StakedERC721(
        address indexed user,
        uint256 amount,
        uint256 timestamp,
        uint256 newTotalStaked,
        uint256 currentRewardRate
    );

    event Withdrawn(
        address indexed owner,
        uint256 amount,
        uint256 timestamp,
        uint256 newTotalStaked,
        uint256 currentRewardRate,
        uint256 rewardsAccrued
    );

    event RewardsClaimed(
        address indexed owner,
        uint256 amount,
        uint256 timestamp,
        uint256 newPendingRewards,
        uint256 totalStaked
    );

    event RewardRateUpdated(
        uint256 oldRate,
        uint256 newRate,
        uint256 timestamp,
        uint256 totalStaked
    );

    event EmergencyWithdrawn(
        address indexed owner,
        uint256 amount,
        uint256 penalty,
        uint256 timestamp,
        uint256 newTotalStaked
    );

    event StakingInitialized(
        address indexed stakingToken,
        uint256 initialRewardRate,
        uint256 timestamp
    );
}
