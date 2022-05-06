//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../Data/Data.sol";
import "../../Utils/Oracle/oracleProxy.sol";
import "../../Handler/Interface/MarketInterface.sol";

import "../../Utils/Tokens/standardIERC20.sol";

import "../../Utils/Utils/SafeMath.sol";

// dont forget to change price

contract Manager {
    using SafeMath for uint256;

    address public Owner;

    ManagerData ManagerDataStorageContract;
    oracleProxy OracleContract;

    standardIERC20 PersisToken;

    struct UserModelAssets {
        uint256 depositAssetSum;
        uint256 borrowAssetSum;
        uint256 marginCallLimitSum;
        uint256 depositAssetBorrowLimitSum;
        uint256 depositAsset;
        uint256 borrowAsset;
        uint256 price;
        uint256 callerPrice;
        uint256 depositAmount;
        uint256 borrowAmount;
        uint256 borrowLimit;
        uint256 marginCallLimit;
        uint256 callerBorrowLimit;
        uint256 userBorrowableAsset;
        uint256 withdrawableAsset;
    }

    mapping(address => UserModelAssets) _UserModelAssetsMapping;

    uint256 public marketsLength;

    modifier OnlyOwner() {
        require(msg.sender == Owner, "OnlyOwner");
        _;
    }

    constructor(address _PersisToken) {
        PersisToken = standardIERC20(_PersisToken);
        Owner = msg.sender;
    }

    function setOracleContract(address _OracleContract)
        external
        OnlyOwner
        returns (bool)
    {
        OracleContract = oracleProxy(_OracleContract);
        return true;
    }

    function setManagerDataStorageContract(address _ManagerDataStorageContract)
        external
        OnlyOwner
        returns (bool)
    {
        ManagerDataStorageContract = ManagerData(_ManagerDataStorageContract);
        return true;
    }

    function registerNewHandler(uint256 _marketID, address _marketAddress)
        external
        OnlyOwner
        returns (bool)
    {
        return _registerNewHandler(_marketID, _marketAddress);
    }

    function _registerNewHandler(uint256 _marketID, address _marketAddress)
        internal
        returns (bool)
    {
        ManagerDataStorageContract.registerNewMarketInCore(
            _marketID,
            _marketAddress
        );
        marketsLength = marketsLength + 1;
        return true;
    }

    function applyInterestHandlers(
        address payable _userAddress,
        uint256 _marketID
    )
        external
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        UserModelAssets memory _UserModelAssets;

        bool _Support;
        address _Address;

        for (uint256 ID = 1; ID <= marketsLength; ID++) {
            (_Support, _Address) = ManagerDataStorageContract.getMarketInfo(ID);

            if (_Support) {
                MarketInterface _HandlerContract = MarketInterface(_Address);

                _HandlerContract.updateRewardManagerData(_userAddress);

                (
                    _UserModelAssets.depositAmount,
                    _UserModelAssets.borrowAmount
                ) = _HandlerContract.updateUserMarketInterest(_userAddress);

                _UserModelAssets.borrowLimit = _HandlerContract
                    .getMarketBorrowLimit();
                _UserModelAssets.marginCallLimit = _HandlerContract
                    .getMarketMarginCallLimit();

                if (ID == _marketID) {
                    _UserModelAssets.price = OracleContract.getTokenPrice(ID);
                    _UserModelAssets.callerPrice = _UserModelAssets.price;
                    _UserModelAssets.callerBorrowLimit = _UserModelAssets
                        .borrowLimit;
                }

                if (
                    _UserModelAssets.depositAmount > 0 ||
                    _UserModelAssets.borrowAmount > 0
                ) {
                    if (ID != _marketID) {
                        _UserModelAssets.price = OracleContract.getTokenPrice(
                            ID
                        );
                    }

                    if (_UserModelAssets.depositAmount > 0) {
                        _UserModelAssets.depositAsset = _UserModelAssets
                            .depositAmount
                            .unifiedMul(_UserModelAssets.price);

                        _UserModelAssets
                            .depositAssetBorrowLimitSum = _UserModelAssets
                            .depositAssetBorrowLimitSum
                            .add(
                                _UserModelAssets.depositAsset.unifiedMul(
                                    _UserModelAssets.borrowLimit
                                )
                            );

                        _UserModelAssets.marginCallLimitSum = _UserModelAssets
                            .marginCallLimitSum
                            .add(
                                _UserModelAssets.depositAsset.unifiedMul(
                                    _UserModelAssets.marginCallLimit
                                )
                            );

                        _UserModelAssets.depositAssetSum = _UserModelAssets
                            .depositAssetSum
                            .add(_UserModelAssets.depositAsset);
                    }

                    if (_UserModelAssets.borrowAmount > 0) {
                        _UserModelAssets.borrowAsset = _UserModelAssets
                            .borrowAmount
                            .unifiedMul(_UserModelAssets.price);

                        _UserModelAssets.borrowAssetSum = _UserModelAssets
                            .borrowAssetSum
                            .add(_UserModelAssets.borrowAsset);
                    }
                }
            }
        }

        if (
            _UserModelAssets.depositAssetBorrowLimitSum >
            _UserModelAssets.borrowAssetSum
        ) {
            _UserModelAssets.userBorrowableAsset = _UserModelAssets
                .depositAssetBorrowLimitSum
                .sub(_UserModelAssets.borrowAssetSum);

            _UserModelAssets.withdrawableAsset = _UserModelAssets
                .depositAssetBorrowLimitSum
                .sub(_UserModelAssets.borrowAssetSum)
                .unifiedDiv(_UserModelAssets.callerBorrowLimit);
        }

        return (
            _UserModelAssets.userBorrowableAsset.unifiedDiv(
                _UserModelAssets.callerPrice
            ),
            _UserModelAssets.withdrawableAsset.unifiedDiv(
                _UserModelAssets.callerPrice
            ),
            _UserModelAssets.marginCallLimitSum,
            _UserModelAssets.depositAssetSum,
            _UserModelAssets.borrowAssetSum,
            _UserModelAssets.callerPrice
        );
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////// Av.. Liquidity

    function getHowMuchUserCanBorrow(
        address payable _userAddress,
        uint256 _marketID
    ) external view returns (uint256) {
        uint256 _userTotalDepositAssets;
        uint256 _userTotalBorrowAssets;

        (
            _userTotalDepositAssets,
            _userTotalBorrowAssets
        ) = _getUserUpdatedParamsFromAllMarkets(_userAddress);
        if (_userTotalDepositAssets == 0) {
            return 0;
        }

        if (_userTotalDepositAssets > _userTotalBorrowAssets) {
            return
                _userTotalDepositAssets.sub(_userTotalBorrowAssets).unifiedDiv(
                    _getUpdatedMarketTokenPrice(_marketID)
                );
        } else {
            return 0;
        }
    }

    function getUserUpdatedParamsFromAllMarkets(address payable _userAddress)
        external
        view
        returns (uint256, uint256)
    {
        return _getUserUpdatedParamsFromAllMarkets(_userAddress);
    }

    function _getUserUpdatedParamsFromAllMarkets(address payable _userAddress)
        internal
        view
        returns (uint256, uint256)
    {
        uint256 _userTotalDepositAssets;
        uint256 _userTotalBorrowAssets;

        for (uint256 ID = 1; ID <= marketsLength; ID++) {
            if (ManagerDataStorageContract.getMarketSupport(ID)) {
                uint256 _userDepositAsset;
                uint256 _userBorrowAsset;

                (
                    _userDepositAsset,
                    _userBorrowAsset
                ) = _getUpdatedInterestAmountsForUser(_userAddress, ID);

                uint256 _marketBorrowLimit = _getMarketBorrowLimit(ID);
                uint256 _userDepositWithLimit = _userDepositAsset.unifiedMul(
                    _marketBorrowLimit
                );

                _userTotalDepositAssets = _userTotalDepositAssets.add(
                    _userDepositWithLimit
                );

                _userTotalBorrowAssets = _userTotalBorrowAssets.add(
                    _userBorrowAsset
                );
            } else {
                continue;
            }
        }

        return (_userTotalDepositAssets, _userTotalBorrowAssets);
    }

    function getUpdatedInterestAmountsForUser(
        address payable _userAddress,
        uint256 _marketID
    ) external view returns (uint256, uint256) {
        return _getUpdatedInterestAmountsForUser(_userAddress, _marketID);
    }

    function _getUpdatedInterestAmountsForUser(
        address payable _userAddress,
        uint256 _marketID
    ) internal view returns (uint256, uint256) {
        uint256 _marketTokenPrice = _getUpdatedMarketTokenPrice(_marketID);

        MarketInterface _MarketInterface = MarketInterface(
            ManagerDataStorageContract.getMarketAddress(_marketID)
        );

        uint256 _userDepositAmount;
        uint256 _userBorrowAmount;

        (_userDepositAmount, _userBorrowAmount) = _MarketInterface
            .getUpdatedInterestAmountsForUser(_userAddress);

        uint256 _userDepositAssets = _userDepositAmount.unifiedMul(
            _marketTokenPrice
        );
        uint256 _userBorrowAssets = _userBorrowAmount.unifiedMul(
            _marketTokenPrice
        );
        return (_userDepositAssets, _userBorrowAssets);
    }

    function getUserLimitsFromAllMarkets(address payable _userAddress)
        external
        view
        returns (uint256, uint256)
    {
        uint256 _userBorrowLimitFromAllMarkets;
        uint256 _userMarginCallLimitLevel;
        (
            _userBorrowLimitFromAllMarkets,
            _userMarginCallLimitLevel
        ) = _getUserLimitsFromAllMarkets(_userAddress);
        return (_userBorrowLimitFromAllMarkets, _userMarginCallLimitLevel);
    }

    function _getUserLimitsFromAllMarkets(address payable _userAddress)
        internal
        view
        returns (uint256, uint256)
    {
        uint256 _userBorrowLimitFromAllMarkets;
        uint256 _userMarginCallLimitLevel;
        for (uint256 ID = 1; ID <= marketsLength; ID++) {
            if (ManagerDataStorageContract.getMarketSupport(ID)) {
                uint256 _userDepositForMarket;
                uint256 _userBorrowForMarket;
                (
                    _userDepositForMarket,
                    _userBorrowForMarket
                ) = _getUpdatedInterestAmountsForUser(_userAddress, ID);
                uint256 _borrowLimit = _getMarketBorrowLimit(ID);
                uint256 _marginCallLimit = _getMarketMarginCallLevel(ID);
                uint256 _userBorrowLimitAsset = _userDepositForMarket
                    .unifiedMul(_borrowLimit);
                uint256 userMarginCallLimitAsset = _userDepositForMarket
                    .unifiedMul(_marginCallLimit);
                _userBorrowLimitFromAllMarkets = _userBorrowLimitFromAllMarkets
                    .add(_userBorrowLimitAsset);
                _userMarginCallLimitLevel = _userMarginCallLimitLevel.add(
                    userMarginCallLimitAsset
                );
            } else {
                continue;
            }
        }

        return (_userBorrowLimitFromAllMarkets, _userMarginCallLimitLevel);
    }

    function getUserFreeToWithdraw(
        address payable _userAddress,
        uint256 _marketID
    ) external view returns (uint256) {
        uint256 _totalUserBorrowAssets;
        uint256 _userDepositAssetsAfterBorrowLimit;
        uint256 _userDepositAssets;
        uint256 _userBorrowAssets;
        for (uint256 ID = 1; ID <= marketsLength; ID++) {
            if (ManagerDataStorageContract.getMarketSupport(ID)) {
                (
                    _userDepositAssets,
                    _userBorrowAssets
                ) = _getUpdatedInterestAmountsForUser(_userAddress, ID);
                _totalUserBorrowAssets = _totalUserBorrowAssets.add(
                    _userBorrowAssets
                );
                _userDepositAssetsAfterBorrowLimit = _userDepositAssetsAfterBorrowLimit
                    .add(
                        _userDepositAssets.unifiedMul(_getMarketBorrowLimit(ID))
                    );
            }
        }

        if (_userDepositAssetsAfterBorrowLimit > _totalUserBorrowAssets) {
            return
                _userDepositAssetsAfterBorrowLimit
                    .sub(_totalUserBorrowAssets)
                    .unifiedDiv(_getMarketBorrowLimit(_marketID))
                    .unifiedDiv(_getUpdatedMarketTokenPrice(_marketID));
        }
        return 0;
    }

    function updateRewardManager(address payable _userAddress)
        external
        returns (bool)
    {
        if (_updateRewardParams()) {
            return _calcRewardParams(_userAddress);
        }

        return false;
    }

    function _updateRewardParams() internal returns (bool) {
        uint256 _currentBlockNumber = block.number;

        uint256 _deltaForBlocks = _currentBlockNumber -
            ManagerDataStorageContract.getLastTimeRewardParamsUpdated();

        ManagerDataStorageContract.setLastTimeRewardParamsUpdated(
            _currentBlockNumber
        );

        if (_deltaForBlocks == 0) {
            return false;
        }

        uint256 _rewardPerBlock = ManagerDataStorageContract
            .getcoreRewardPerBlock();
        uint256 _rewardDecrement = ManagerDataStorageContract
            .getcoreRewardDecrement();
        uint256 _rewardTotalAmount = ManagerDataStorageContract
            .getcoreTotalRewardAmounts();

        uint256 _timeToFinishReward = _rewardPerBlock.unifiedDiv(
            _rewardDecrement
        );

        if (_timeToFinishReward >= _deltaForBlocks.mul(SafeMath.unifiedPoint)) {
            _timeToFinishReward = _timeToFinishReward.sub(
                _deltaForBlocks.mul(SafeMath.unifiedPoint)
            );
        } else {
            return _updateRewardParamsInDataStorage(0, _rewardDecrement, 0);
        }

        if (_rewardTotalAmount >= _rewardPerBlock.mul(_deltaForBlocks)) {
            _rewardTotalAmount =
                _rewardTotalAmount -
                _rewardPerBlock.mul(_deltaForBlocks);
        } else {
            return _updateRewardParamsInDataStorage(0, _rewardDecrement, 0);
        }

        _rewardPerBlock = _rewardTotalAmount.mul(2).unifiedDiv(
            _timeToFinishReward.add(SafeMath.unifiedPoint)
        );
        /* To incentivze the update operation, the operator get paid with the
		reward token */
        return
            _updateRewardParamsInDataStorage(
                _rewardPerBlock,
                _rewardDecrement,
                _rewardTotalAmount
            );
    }

    function _updateRewardParamsInDataStorage(
        uint256 _rewardPerBlock,
        uint256 _dcrement,
        uint256 _total
    ) internal returns (bool) {
        ManagerDataStorageContract.setCoreRewardPerBlock(_rewardPerBlock);
        ManagerDataStorageContract.setCoreRewardDecrement(_dcrement);
        ManagerDataStorageContract.setCoreTotalRewardAmounts(_total);
        return true;
    }

    function _calcRewardParams(address payable _userAddress)
        internal
        returns (bool)
    {
        uint256[] memory handlerAlphaRateBaseAsset = new uint256[](
            marketsLength
        );

        uint256 handlerID;
        uint256 alphaRateBaseGlobalAssetSum;

        for (uint256 ID = 1; ID <= marketsLength; ID++) {
            handlerAlphaRateBaseAsset[handlerID + 1] = _getAlphaBaseAsset(
                handlerID + 1
            );
            alphaRateBaseGlobalAssetSum = alphaRateBaseGlobalAssetSum.add(
                handlerAlphaRateBaseAsset[handlerID + 1]
            );
        }

        handlerID = 0;

        for (uint256 ID = 1; ID <= marketsLength; ID++) {
            MarketInterface _MarketInterface = MarketInterface(
                ManagerDataStorageContract.getMarketAddress(ID)
            );

            _MarketInterface.updateRewardManagerData(_userAddress);

            _MarketInterface.updateRewardPerBlock(
                ManagerDataStorageContract.getcoreRewardPerBlock().unifiedMul(
                    handlerAlphaRateBaseAsset[handlerID + 1].unifiedDiv(
                        alphaRateBaseGlobalAssetSum
                    )
                )
            );
        }

        return true;
    }

    function _getAlphaBaseAsset(uint256 _handlerID)
        internal
        view
        returns (uint256)
    {
        MarketInterface _MarketContract = MarketInterface(
            ManagerDataStorageContract.getMarketAddress(_handlerID)
        );

        uint256 _depositAmount = _MarketContract.getMarketDepositTotalAmount();
        uint256 _borrowAmount = _MarketContract.getMarketBorrowTotalAmount();

        uint256 _alpha = ManagerDataStorageContract.getAlphaRate();
        uint256 _price = _getUpdatedMarketTokenPrice(_handlerID);
        return
            _calcAlphaBaseAmount(_alpha, _depositAmount, _borrowAmount)
                .unifiedMul(_price);
    }

    function _calcAlphaBaseAmount(
        uint256 _alpha,
        uint256 _depositAmount,
        uint256 _borrowAmount
    ) internal pure returns (uint256) {
        return
            _depositAmount.unifiedMul(_alpha).add(
                _borrowAmount.unifiedMul(SafeMath.unifiedPoint.sub(_alpha))
            );
    }

    function rewardClaimAll(address payable userAddr) external returns (bool) {
        uint256 claimAmountSum;
        for (uint256 ID = 1; ID <= marketsLength; ID++) {
            MarketInterface _MarketInterface = MarketInterface(
                ManagerDataStorageContract.getMarketAddress(ID)
            );

            _MarketInterface.updateRewardManagerData(userAddr);

            claimAmountSum = claimAmountSum.add(
                _MarketInterface.claimRewardAmountUser(userAddr)
            );
        }

        PersisToken.transfer(userAddr, claimAmountSum);

        return true;
    }

    function getUpdatedUserRewardAmount(address payable userAddr)
        external
        view
        returns (uint256)
    {
        uint256 UpdatedUserRewardAmount;
        for (uint256 ID = 1; ID <= marketsLength; ID++) {
            MarketInterface _MarketInterface = MarketInterface(
                ManagerDataStorageContract.getMarketAddress(ID)
            );

            UpdatedUserRewardAmount = UpdatedUserRewardAmount.add(
                _MarketInterface.getUpdatedUserRewardAmount(userAddr)
            );
        }

        return UpdatedUserRewardAmount;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////// MANAGER TOOLS

    function getUpdatedMarketTokenPrice(uint256 _marketID)
        external
        view
        returns (uint256)
    {
        return _getUpdatedMarketTokenPrice(_marketID);
    }

    function _getUpdatedMarketTokenPrice(uint256 _marketID)
        internal
        view
        returns (uint256)
    {
        return (OracleContract.getTokenPrice(_marketID));
    }

    function getMarketMarginCallLevel(uint256 _marketID)
        external
        view
        returns (uint256)
    {
        return _getMarketMarginCallLevel(_marketID);
    }

    function _getMarketMarginCallLevel(uint256 _marketID)
        internal
        view
        returns (uint256)
    {
        MarketInterface _MarketInterface = MarketInterface(
            ManagerDataStorageContract.getMarketAddress(_marketID)
        );

        return _MarketInterface.getMarketMarginCallLimit();
    }

    function getMarketBorrowLimit(uint256 _marketID)
        external
        view
        returns (uint256)
    {
        return _getMarketBorrowLimit(_marketID);
    }

    function _getMarketBorrowLimit(uint256 _marketID)
        internal
        view
        returns (uint256)
    {
        MarketInterface _MarketInterface = MarketInterface(
            ManagerDataStorageContract.getMarketAddress(_marketID)
        );

        return _MarketInterface.getMarketBorrowLimit();
    }
}
