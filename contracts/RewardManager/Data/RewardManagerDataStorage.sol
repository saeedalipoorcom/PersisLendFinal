//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract RewardManagerDataStorage {
    address payable Owner;

    address RewardManagerContract;

    struct marketRewardModel {
        uint256 rewardLane;
        uint256 rewardLaneUpdateAt;
        uint256 rewardPerBlock;
    }
    marketRewardModel MarketRewardModel;

    struct userRewardModel {
        uint256 rewardLane;
        uint256 rewardLaneUpdateAt;
        uint256 rewardAmount;
    }
    mapping(address => userRewardModel) userRewardModelMapping;

    uint256 betaRate;

    constructor() {
        Owner = payable(msg.sender);
        betaRate = 5 * (10**17);
        MarketRewardModel.rewardLaneUpdateAt = block.number;
    }

    function setRewardManagerContract(address _RewardManagerContract)
        external
        returns (bool)
    {
        RewardManagerContract = _RewardManagerContract;
        return true;
    }

    function updateRewardPerBlock(uint256 _rewardPerBlock)
        external
        returns (bool)
    {
        MarketRewardModel.rewardPerBlock = _rewardPerBlock;
        return true;
    }

    function updateMarketRewardModel(
        uint256 _rewardLane,
        uint256 _rewardLaneUpdateAt,
        uint256 _rewardPerBlock
    ) external returns (bool) {
        marketRewardModel memory _MarketRewardModel;
        _MarketRewardModel.rewardLane = _rewardLane;
        _MarketRewardModel.rewardLaneUpdateAt = _rewardLaneUpdateAt;
        _MarketRewardModel.rewardPerBlock = _rewardPerBlock;
        MarketRewardModel = _MarketRewardModel;
        return true;
    }

    function updateUserRewardModel(
        address _userAddress,
        uint256 _rewardLane,
        uint256 _rewardLaneUpdateAt,
        uint256 _rewardAmount
    ) external returns (bool) {
        userRewardModel memory _userRewardModel;
        _userRewardModel.rewardLane = _rewardLane;
        _userRewardModel.rewardLaneUpdateAt = _rewardLaneUpdateAt;
        _userRewardModel.rewardAmount = _rewardAmount;
        userRewardModelMapping[_userAddress] = _userRewardModel;
        return true;
    }

    function setBetaRate(uint256 _betaRate) external returns (bool) {
        betaRate = _betaRate;
        return true;
    }

    function getMarketRewardUserRewardModel(address _userAddress)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        marketRewardModel memory _marketRewardModel = MarketRewardModel;
        userRewardModel memory _userRewardModel = userRewardModelMapping[
            _userAddress
        ];
        return (
            _marketRewardModel.rewardLane,
            _marketRewardModel.rewardLaneUpdateAt,
            _marketRewardModel.rewardPerBlock,
            _userRewardModel.rewardLane,
            _userRewardModel.rewardLaneUpdateAt,
            _userRewardModel.rewardAmount
        );
    }

    function getMarketRewardModel()
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        marketRewardModel memory _marketRewardModel = MarketRewardModel;
        return (
            _marketRewardModel.rewardLane,
            _marketRewardModel.rewardLaneUpdateAt,
            _marketRewardModel.rewardPerBlock
        );
    }

    function getUserRewardModel(address _userAddress)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        userRewardModel memory _userRewardModel = userRewardModelMapping[
            _userAddress
        ];
        return (
            _userRewardModel.rewardLane,
            _userRewardModel.rewardLaneUpdateAt,
            _userRewardModel.rewardAmount
        );
    }

    function getBetaRate() external view returns (uint256) {
        return betaRate;
    }
}
