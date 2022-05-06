//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../../Core/Contracts/Manager.sol";
import "../../Handler/Data/Data.sol";
import "../Data/RewardManagerDataStorage.sol";

contract RewardManager {
    address payable Owner;

    uint256 constant startPoint = 10**18;

    address ManagerContract;
    MarketData MarketDataStorageContract;
    RewardManagerDataStorage RewardManagerDataStorageContract;

    struct marketRewardModel {
        uint256 rewardTicker;
        uint256 rewardTickerUpdateAt;
        uint256 rewardPerBlock;
    }

    struct userRewardModel {
        uint256 rewardTicker;
        uint256 rewardTickerUpdateAt;
        uint256 rewardAmount;
    }

    function setManagerContractAddress(address _managerContractAddress)
        external
        returns (bool)
    {
        ManagerContract = _managerContractAddress;
        return true;
    }

    function setMarketDataStorageContract(
        address _MarketDataStorageContractAddress
    ) external returns (bool) {
        MarketDataStorageContract = MarketData(
            _MarketDataStorageContractAddress
        );
        return true;
    }

    function setRewardManagerDataStorageContract(
        address _RewardManagerDataStorageContractAddress
    ) external returns (bool) {
        RewardManagerDataStorageContract = RewardManagerDataStorage(
            _RewardManagerDataStorageContractAddress
        );
        return true;
    }

    function updateRewardPerBlock(uint256 _rewardPerBlock)
        external
        returns (bool)
    {
        return
            RewardManagerDataStorageContract.updateRewardPerBlock(
                _rewardPerBlock
            );
    }

    function updateRewardManagerData(address payable _userAddress)
        external
        returns (bool)
    {
        return _updateRewardManagerData(_userAddress);
    }

    function _updateRewardManagerData(address payable _userAddress)
        internal
        returns (bool)
    {
        marketRewardModel memory _marketRewardModel;
        userRewardModel memory _userRewardModel;

        (
            _marketRewardModel.rewardTicker,
            _marketRewardModel.rewardTickerUpdateAt,
            _marketRewardModel.rewardPerBlock,
            _userRewardModel.rewardTicker,
            _userRewardModel.rewardTickerUpdateAt,
            _userRewardModel.rewardAmount
        ) = RewardManagerDataStorageContract.getMarketRewardUserRewardModel(
            _userAddress
        );

        uint256 currentBlockNum = block.number;
        uint256 _marketDepositTotalAmount;
        uint256 _marketBorrowTotalAmount;
        uint256 _userDepositAmount;
        uint256 _userBorrowAmount;
        (
            _marketDepositTotalAmount,
            _marketBorrowTotalAmount,
            _userDepositAmount,
            _userBorrowAmount
        ) = MarketDataStorageContract.getAmounts(_userAddress);

        if (_marketRewardModel.rewardTickerUpdateAt < currentBlockNum) {
            uint256 _delta = sub(
                currentBlockNum,
                _marketRewardModel.rewardTickerUpdateAt
            );

            uint256 betaRateBaseTotalAmount = _calcBetaBaseAmount(
                RewardManagerDataStorageContract.getBetaRate(),
                _marketDepositTotalAmount,
                _marketBorrowTotalAmount
            );
            if (betaRateBaseTotalAmount != 0) {
                _marketRewardModel.rewardTicker = add(
                    _marketRewardModel.rewardTicker,
                    _calcrewardTickerDistance(
                        _delta,
                        _marketRewardModel.rewardPerBlock,
                        betaRateBaseTotalAmount
                    )
                );
            }

            RewardManagerDataStorageContract.updateMarketRewardModel(
                _marketRewardModel.rewardTicker,
                currentBlockNum,
                _marketRewardModel.rewardPerBlock
            );
        }

        if (_userRewardModel.rewardTickerUpdateAt < currentBlockNum) {
            uint256 betaRateBaseUserAmount = _calcBetaBaseAmount(
                RewardManagerDataStorageContract.getBetaRate(),
                _userDepositAmount,
                _userBorrowAmount
            );
            if (betaRateBaseUserAmount != 0) {
                _userRewardModel.rewardAmount = add(
                    _userRewardModel.rewardAmount,
                    unifiedMul(
                        betaRateBaseUserAmount,
                        sub(
                            _marketRewardModel.rewardTicker,
                            _userRewardModel.rewardTicker
                        )
                    )
                );
            }

            RewardManagerDataStorageContract.updateUserRewardModel(
                _userAddress,
                _marketRewardModel.rewardTicker,
                currentBlockNum,
                _userRewardModel.rewardAmount
            );
            return true;
        }

        return false;
    }

    function _calcBetaBaseAmount(
        uint256 _beta,
        uint256 _depositAmount,
        uint256 _borrowAmount
    ) internal pure returns (uint256) {
        return
            add(
                unifiedMul(_depositAmount, _beta),
                unifiedMul(_borrowAmount, sub(startPoint, _beta))
            );
    }

    function _calcrewardTickerDistance(
        uint256 _delta,
        uint256 _rewardPerBlock,
        uint256 _total
    ) internal pure returns (uint256) {
        return mul(_delta, unifiedDiv(_rewardPerBlock, _total));
    }

    function getBetaRateBaseTotalAmount() external view returns (uint256) {
        return _getBetaRateBaseTotalAmount();
    }

    function _getBetaRateBaseTotalAmount() internal view returns (uint256) {
        uint256 depositTotalAmount;
        uint256 borrowTotalAmount;
        (depositTotalAmount, borrowTotalAmount) = MarketDataStorageContract
            .getMarketAmounts();
        return
            _calcBetaBaseAmount(
                RewardManagerDataStorageContract.getBetaRate(),
                depositTotalAmount,
                borrowTotalAmount
            );
    }

    function getBetaRateBaseUserAmount(address payable userAddr)
        external
        view
        returns (uint256)
    {
        return _getBetaRateBaseUserAmount(userAddr);
    }

    function _getBetaRateBaseUserAmount(address payable userAddr)
        internal
        view
        returns (uint256)
    {
        uint256 depositUserAmount;
        uint256 borrowUserAmount;
        (depositUserAmount, borrowUserAmount) = MarketDataStorageContract
            .getUserAmounts(userAddr);
        return
            _calcBetaBaseAmount(
                RewardManagerDataStorageContract.getBetaRate(),
                depositUserAmount,
                borrowUserAmount
            );
    }

    function claimRewardAmountUser(address payable userAddr)
        external
        returns (uint256)
    {
        return _claimRewardAmountUser(userAddr);
    }

    function _claimRewardAmountUser(address payable userAddr)
        internal
        returns (uint256)
    {
        userRewardModel memory _userRewardModel;
        uint256 currentBlockNum = block.number;
        (
            _userRewardModel.rewardTicker,
            _userRewardModel.rewardTickerUpdateAt,
            _userRewardModel.rewardAmount
        ) = RewardManagerDataStorageContract.getUserRewardModel(userAddr);

        /* reset the user reward */
        RewardManagerDataStorageContract.updateUserRewardModel(
            userAddr,
            _userRewardModel.rewardTicker,
            currentBlockNum,
            0
        );
        return _userRewardModel.rewardAmount;
    }

    function getMarketRewardInfo()
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return RewardManagerDataStorageContract.getMarketRewardModel();
    }

    function getUserRewardInfo(address payable userAddr)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return RewardManagerDataStorageContract.getUserRewardModel(userAddr);
    }

    function getBetaRate() external view returns (uint256) {
        return RewardManagerDataStorageContract.getBetaRate();
    }

    function getUpdatedUserRewardAmount(address payable _userAddress)
        external
        view
        returns (uint256)
    {
        return _getUpdatedUserRewardAmount(_userAddress);
    }

    function _getUpdatedUserRewardAmount(address payable _userAddress)
        internal
        view
        returns (uint256)
    {
        marketRewardModel memory _marketRewardModel;
        userRewardModel memory _userRewardModel;

        (
            _marketRewardModel.rewardTicker,
            _marketRewardModel.rewardTickerUpdateAt,
            _marketRewardModel.rewardPerBlock,
            _userRewardModel.rewardTicker,
            _userRewardModel.rewardTickerUpdateAt,
            _userRewardModel.rewardAmount
        ) = RewardManagerDataStorageContract.getMarketRewardUserRewardModel(
            _userAddress
        );

        uint256 currentBlockNum = block.number;
        uint256 _marketDepositTotalAmount;
        uint256 _marketBorrowTotalAmount;
        uint256 _userDepositAmount;
        uint256 _userBorrowAmount;
        (
            _marketDepositTotalAmount,
            _marketBorrowTotalAmount,
            _userDepositAmount,
            _userBorrowAmount
        ) = MarketDataStorageContract.getAmounts(_userAddress);

        if (_marketRewardModel.rewardTickerUpdateAt < currentBlockNum) {
            uint256 _delta = sub(
                currentBlockNum,
                _marketRewardModel.rewardTickerUpdateAt
            );
            uint256 betaRateBaseTotalAmount = _calcBetaBaseAmount(
                RewardManagerDataStorageContract.getBetaRate(),
                _marketDepositTotalAmount,
                _marketBorrowTotalAmount
            );
            if (betaRateBaseTotalAmount != 0) {
                _marketRewardModel.rewardTicker = add(
                    _marketRewardModel.rewardTicker,
                    _calcrewardTickerDistance(
                        _delta,
                        _marketRewardModel.rewardPerBlock,
                        betaRateBaseTotalAmount
                    )
                );
            }
        }

        if (_userRewardModel.rewardTickerUpdateAt < currentBlockNum) {
            uint256 betaRateBaseUserAmount = _calcBetaBaseAmount(
                RewardManagerDataStorageContract.getBetaRate(),
                _userDepositAmount,
                _userBorrowAmount
            );
            if (betaRateBaseUserAmount != 0) {
                _userRewardModel.rewardAmount = add(
                    _userRewardModel.rewardAmount,
                    unifiedMul(
                        betaRateBaseUserAmount,
                        sub(
                            _marketRewardModel.rewardTicker,
                            _userRewardModel.rewardTicker
                        )
                    )
                );
            }
        }

        return _userRewardModel.rewardAmount;
    }

    /* ******************* Safe Math ******************* */
    // from: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol
    // Subject to the MIT license.

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "add overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return _sub(a, b, "sub overflow");
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return _mul(a, b);
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return _div(a, b, "div by zero");
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return _mod(a, b, "mod by zero");
    }

    function _sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    function _mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require((c / a) == b, "mul overflow");
        return c;
    }

    function _div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    function _mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }

    function unifiedDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return _div(_mul(a, startPoint), b, "unified div by zero");
    }

    function unifiedMul(uint256 a, uint256 b) internal pure returns (uint256) {
        return _div(_mul(a, b), startPoint, "unified mul by zero");
    }

    function signedAdd(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require(
            ((b >= 0) && (c >= a)) || ((b < 0) && (c < a)),
            "SignedSafeMath: addition overflow"
        );
        return c;
    }

    function signedSub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require(
            ((b >= 0) && (c <= a)) || ((b < 0) && (c > a)),
            "SignedSafeMath: subtraction overflow"
        );
        return c;
    }
}
