// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibParametersStorage} from "../storage/LibParametersStorage.sol";
import {LibTypes} from "./LibTypes.sol";
import {LibErrors} from "./LibErrors.sol";
import {LibEvents} from "./LibEvents.sol";
import {LibConstants} from "./LibConstants.sol";

library LibParametersLogic {
    // Disclaimer: Hardcoded values requested by business logic

    struct RangeSetup {
        LibTypes.ParameterField field;
        uint256 index;
        uint256 min;
        uint256 max;
    }

    function init(
        LibTypes.NFT[] memory nfts,
        LibTypes.RangesNFT[] memory nftRanges,
        LibTypes.GiftNFT[] memory gifts,
        LibTypes.RangesGift[] memory giftRanges
    ) internal {
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        ps.regularTypes.push();
        ps.giftTypes.push();
        ps.minGiftValues[LibTypes.GiftField.Price].push();
        ps.maxGiftValues[LibTypes.GiftField.Price].push();
        ps.minGiftValues[LibTypes.GiftField.Limit].push();
        ps.maxGiftValues[LibTypes.GiftField.Limit].push();
        ps.minGiftValues[LibTypes.GiftField.Supply].push();
        ps.maxGiftValues[LibTypes.GiftField.Supply].push();

        ps.txFeeMin = 0.00003 ether;
        ps.txFeeMax = 0.005 ether;

        for (uint256 i = 0; i < nfts.length; i++) {
            nfts[i].unlocksAfter += uint64(block.timestamp);
            ps.regularTypes.push(nfts[i]);
        }

        for (uint256 i = 0; i < gifts.length; i++) {
            addGiftNFT(gifts[i], giftRanges[i]);
        }

        uint8[22] memory distributionPercents = [
            0,
            10,
            20,
            20,
            30,
            30,
            40,
            40,
            40,
            40,
            40,
            40,
            40,
            40,
            50,
            0,
            0,
            0,
            0,
            0,
            0,
            0
        ];
        ps.parameters = LibTypes.Parameters({
            accumulativeTransferFee: 200,
            accumulativePercent: 200,
            accumulativeUseFee: 200,
            sponsorPercentFirst: 300,
            sponsorPercent: 200,
            tokenReservePercentFirst: 0,
            tokenReservePercent: 100,
            toDevsPercentFirst: 70,
            toDevsPercent: 70,
            matchingPercent: 50,
            fee: 50,
            loanFee: 50,
            withdrawalFee: 0,
            giftPrice: 0,
            claimFrozenSponsorPercent: 300,
            businessSaleFee: 500 * 10 ** 18,
            accumulativeDecayTime: 120 days,
            decayTimeNFTM: 72 hours,
            totalDistributePercent: 480,
            giftHoldLimit: 100,
            businessSale: false,
            matchingThresholds: [0, uint80(1000 * 10 ** 18), uint80(3000 * 10 ** 18)],
            accumulativeClaimDistribute: [uint16(300), uint16(0), uint16(700)],
            accumulativeClaimDistributeGift: [uint16(200), 0, uint16(800)],
            distribution: distributionPercents,
            autoSellPeriods: [120 days, 90 days, 90 days, 65 days]
        });

        _setRangesNFT(nftRanges, nfts);
        _setRanges();

        _checkParameters();
        emit LibEvents.InitialParameters(ps.parameters, getConstants());
    }

    function addGiftNFT(LibTypes.GiftNFT memory gift, LibTypes.RangesGift memory ranges) internal {
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        gift.level = uint32(ps.giftTypes.length);
        ps.giftTypes.push(gift);
        _setRangeGift(ps, LibTypes.GiftField.Price, ranges.priceMin, ranges.priceMax);
        _setRangeGift(ps, LibTypes.GiftField.Limit, ranges.limitMin, ranges.limitMax);
        _setRangeGift(ps, LibTypes.GiftField.Supply, 0, type(uint256).max);
        emit LibEvents.NewGiftNFT(gift.level, gift, ranges);
    }

    function _setRangeGift(
        LibParametersStorage.ParametersStorage storage ps,
        LibTypes.GiftField field,
        uint256 min,
        uint256 max
    ) private {
        ps.minGiftValues[field].push(min);
        ps.maxGiftValues[field].push(max);
    }

    function _updateGiftField(
        LibParametersStorage.ParametersStorage storage ps,
        uint32 level,
        LibTypes.GiftUpdate calldata update
    ) private {
        uint256 minVal = ps.minGiftValues[update.field][level];
        uint256 maxVal = ps.maxGiftValues[update.field][level];
        if (update.value < minVal || update.value > maxVal) revert LibErrors.OutOfRange(update.value, minVal, maxVal);
        if (update.field == LibTypes.GiftField.Price) {
            ps.giftTypes[level].price = update.value;
        } else if (update.field == LibTypes.GiftField.Limit) {
            ps.giftTypes[level].limit = update.value;
        } else if (update.field == LibTypes.GiftField.Supply) {
            ps.giftTypes[level].supply = update.value;
        } else {
            revert LibErrors.UnknownField();
        }
    }

    function _applyParameterUpdate(LibTypes.ParameterUpdate calldata update) private {
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        uint256 minVal = ps.minParamValues[update.field][update.index];
        uint256 maxVal = ps.maxParamValues[update.field][update.index];
        if (update.value < minVal || update.value > maxVal) revert LibErrors.OutOfRange(update.value, minVal, maxVal);
        if (update.field == LibTypes.ParameterField.AccumulativeTransferFee) {
            ps.parameters.accumulativeTransferFee = update.value;
        } else if (update.field == LibTypes.ParameterField.AccumulativePercent) {
            ps.parameters.accumulativePercent = update.value;
        } else if (update.field == LibTypes.ParameterField.AccumulativeUseFee) {
            ps.parameters.accumulativeUseFee = update.value;
        } else if (update.field == LibTypes.ParameterField.SponsorPercentFirst) {
            ps.parameters.sponsorPercentFirst = update.value;
        } else if (update.field == LibTypes.ParameterField.SponsorPercent) {
            ps.parameters.sponsorPercent = update.value;
        } else if (update.field == LibTypes.ParameterField.TokenReservePercentFirst) {
            ps.parameters.tokenReservePercentFirst = update.value;
        } else if (update.field == LibTypes.ParameterField.TokenReservePercent) {
            ps.parameters.tokenReservePercent = update.value;
        } else if (update.field == LibTypes.ParameterField.ToDevsPercentFirst) {
            ps.parameters.toDevsPercentFirst = update.value;
        } else if (update.field == LibTypes.ParameterField.ToDevsPercent) {
            ps.parameters.toDevsPercent = update.value;
        } else if (update.field == LibTypes.ParameterField.Fee) {
            ps.parameters.fee = update.value;
        } else if (update.field == LibTypes.ParameterField.LoanFee) {
            ps.parameters.loanFee = update.value;
        } else if (update.field == LibTypes.ParameterField.WithdrawalFee) {
            ps.parameters.withdrawalFee = update.value;
        } else if (update.field == LibTypes.ParameterField.GiftPrice) {
            ps.parameters.giftPrice = update.value;
        } else if (update.field == LibTypes.ParameterField.ClaimFrozenSponsorPercent) {
            ps.parameters.claimFrozenSponsorPercent = update.value;
        } else if (update.field == LibTypes.ParameterField.BusinessSaleFee) {
            ps.parameters.businessSaleFee = update.value;
        } else if (update.field == LibTypes.ParameterField.AccumulativeDecayTime) {
            ps.parameters.accumulativeDecayTime = uint32(update.value);
        } else if (update.field == LibTypes.ParameterField.DecayTimeNFTM) {
            ps.parameters.decayTimeNFTM = uint32(update.value);
        } else if (update.field == LibTypes.ParameterField.TotalDistributePercent) {
            ps.parameters.totalDistributePercent = uint16(update.value);
        } else if (update.field == LibTypes.ParameterField.GiftHoldLimit) {
            ps.parameters.giftHoldLimit = uint16(update.value);
        } else if (update.field == LibTypes.ParameterField.BusinessSale) {
            ps.parameters.businessSale = update.value == 1;
        } else if (update.field == LibTypes.ParameterField.MatchingThreshold) {
            ps.parameters.matchingThresholds[update.index] = uint80(update.value);
        } else if (update.field == LibTypes.ParameterField.AccumulativeClaimDistributeSponsor) {
            ps.parameters.accumulativeClaimDistribute[0] = uint16(update.value);
        } else if (update.field == LibTypes.ParameterField.AccumulativeClaimDistributeCompany) {
            ps.parameters.accumulativeClaimDistribute[1] = uint16(update.value);
        } else if (update.field == LibTypes.ParameterField.AccumulativeClaimDistributeTokenReserve) {
            ps.parameters.accumulativeClaimDistribute[2] = uint16(update.value);
        } else if (update.field == LibTypes.ParameterField.AccumulativeClaimDistributeGiftSponsor) {
            ps.parameters.accumulativeClaimDistributeGift[0] = uint16(update.value);
        } else if (update.field == LibTypes.ParameterField.AccumulativeClaimDistributeGiftCompany) {
            ps.parameters.accumulativeClaimDistributeGift[1] = uint16(update.value);
        } else if (update.field == LibTypes.ParameterField.AccumulativeClaimDistributeGiftTokenReserve) {
            ps.parameters.accumulativeClaimDistributeGift[2] = uint16(update.value);
        } else if (update.field == LibTypes.ParameterField.AutoSellPeriods) {
            ps.parameters.autoSellPeriods[update.index] = uint24(update.value);
        } else if (update.field == LibTypes.ParameterField.Distribution) {
            ps.parameters.distribution[update.index] = uint8(update.value);
        } else {
            revert LibErrors.UnknownField();
        }
    }

    function _checkParameters() private view {
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();

        uint256 accumulativeClaimDistributeSum;
        uint256 accumulativeClaimDistributeGiftSum;
        for (uint256 index; index < 3; index++) {
            accumulativeClaimDistributeSum += ps.parameters.accumulativeClaimDistribute[index];
            accumulativeClaimDistributeGiftSum += ps.parameters.accumulativeClaimDistributeGift[index];
        }
        if (
            accumulativeClaimDistributeSum != LibConstants.DENOMINATOR ||
            accumulativeClaimDistributeGiftSum != LibConstants.DENOMINATOR
        ) revert LibErrors.WrongPercentageSum(LibTypes.PercentageError.AccumulativeClaimDistribute);

        uint256 treeDistributed;
        for (uint256 index; index < ps.parameters.distribution.length; index++) {
            treeDistributed += ps.parameters.distribution[index];
        }
        if (treeDistributed != ps.parameters.totalDistributePercent)
            revert LibErrors.WrongPercentageSum(LibTypes.PercentageError.TreeDistributePercent);

        uint256 totalDistributedFirst = ps.parameters.totalDistributePercent +
            ps.parameters.sponsorPercentFirst +
            ps.parameters.tokenReservePercentFirst +
            ps.parameters.toDevsPercentFirst +
            (ps.parameters.sponsorPercentFirst * ps.parameters.matchingPercent * 3) /
            LibConstants.DENOMINATOR;
        uint256 totalDistributed = ps.parameters.totalDistributePercent +
            ps.parameters.sponsorPercent +
            ps.parameters.tokenReservePercent +
            ps.parameters.toDevsPercent +
            (ps.parameters.sponsorPercent * ps.parameters.matchingPercent * 3) /
            LibConstants.DENOMINATOR;
        if (totalDistributedFirst > LibConstants.DENOMINATOR || totalDistributed > LibConstants.DENOMINATOR)
            revert LibErrors.WrongPercentageSum(LibTypes.PercentageError.TotalDistributePercent);
    }

    function _applyNftUpdate(
        LibParametersStorage.ParametersStorage storage ps,
        uint256 level,
        LibTypes.NFTUpdate calldata update
    ) internal {
        uint256 minVal = ps.minNftValues[update.field][level];
        uint256 maxVal = ps.maxNftValues[update.field][level];
        if (update.value < minVal || update.value > maxVal) revert LibErrors.OutOfRange(update.value, minVal, maxVal);

        if (update.field == LibTypes.NftField.Price) {
            ps.regularTypes[level].price = update.value;
        } else if (update.field == LibTypes.NftField.Limit) {
            ps.regularTypes[level].limit = update.value;
        } else if (update.field == LibTypes.NftField.AutoBuys) {
            ps.regularTypes[level].autoBuys = uint32(update.value);
        } else if (update.field == LibTypes.NftField.FarmingTime) {
            ps.regularTypes[level].farmingTime = uint32(update.value);
        } else if (update.field == LibTypes.NftField.MiningTime) {
            ps.regularTypes[level].miningTime = uint32(update.value);
        } else if (update.field == LibTypes.NftField.EarnLevels) {
            ps.regularTypes[level].earnLevels = uint32(update.value);
        }
    }

    function _setRange(
        LibParametersStorage.ParametersStorage storage ps,
        LibTypes.ParameterField field,
        uint256 minVal,
        uint256 maxVal
    ) private returns (LibTypes.ParameterRange memory) {
        return _setRange(ps, field, 0, minVal, maxVal);
    }

    function _setRange(
        LibParametersStorage.ParametersStorage storage ps,
        LibTypes.ParameterField field,
        uint256 index,
        uint256 minVal,
        uint256 maxVal
    ) private returns (LibTypes.ParameterRange memory) {
        ps.minParamValues[field][index] = minVal;
        ps.maxParamValues[field][index] = maxVal;
        return LibTypes.ParameterRange(field, index, minVal, maxVal);
    }

    function _setRanges() private {
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        LibTypes.ParameterRange[55] memory ranges;

        RangeSetup[55] memory setups = [
            RangeSetup(LibTypes.ParameterField.ToDevsPercentFirst, 0, 20, 100),
            RangeSetup(LibTypes.ParameterField.ToDevsPercent, 0, 20, 100),
            RangeSetup(LibTypes.ParameterField.AccumulativePercent, 0, 150, 300),
            RangeSetup(LibTypes.ParameterField.AccumulativeUseFee, 0, 100, 300),
            RangeSetup(LibTypes.ParameterField.AccumulativeClaimDistributeSponsor, 0, 0, 300),
            RangeSetup(LibTypes.ParameterField.AccumulativeClaimDistributeCompany, 0, 0, 300),
            RangeSetup(LibTypes.ParameterField.AccumulativeClaimDistributeTokenReserve, 0, 500, 1000),
            RangeSetup(LibTypes.ParameterField.AccumulativeClaimDistributeGiftSponsor, 0, 0, 300),
            RangeSetup(LibTypes.ParameterField.AccumulativeClaimDistributeGiftCompany, 0, 0, 300),
            RangeSetup(LibTypes.ParameterField.AccumulativeClaimDistributeGiftTokenReserve, 0, 500, 1000),
            RangeSetup(LibTypes.ParameterField.AccumulativeDecayTime, 0, 90 days, 180 days),
            RangeSetup(LibTypes.ParameterField.MatchingThreshold, 0, 0, 0),
            RangeSetup(LibTypes.ParameterField.MatchingThreshold, 1, 1_000 * 10 ** 18, 5_000 * 10 ** 18),
            RangeSetup(LibTypes.ParameterField.MatchingThreshold, 2, 3_000 * 10 ** 18, 7_000 * 10 ** 18),
            RangeSetup(LibTypes.ParameterField.Fee, 0, 50, 150),
            RangeSetup(LibTypes.ParameterField.LoanFee, 0, 0, 50),
            RangeSetup(LibTypes.ParameterField.WithdrawalFee, 0, 0, 50),
            RangeSetup(LibTypes.ParameterField.GiftPrice, 0, 0, 25 * 10 ** 18),
            RangeSetup(LibTypes.ParameterField.ClaimFrozenSponsorPercent, 0, 0, 300),
            RangeSetup(LibTypes.ParameterField.BusinessSaleFee, 0, 0, 500 * 10 ** 18),
            RangeSetup(LibTypes.ParameterField.TokenReservePercentFirst, 0, 0, 300),
            RangeSetup(LibTypes.ParameterField.TokenReservePercent, 0, 100, 300),
            RangeSetup(LibTypes.ParameterField.AccumulativeTransferFee, 0, 100, 300),
            RangeSetup(LibTypes.ParameterField.DecayTimeNFTM, 0, 24 hours, 96 hours),
            RangeSetup(LibTypes.ParameterField.TotalDistributePercent, 0, 0, 1000),
            RangeSetup(LibTypes.ParameterField.GiftHoldLimit, 0, 1, 400),
            RangeSetup(LibTypes.ParameterField.BusinessSale, 0, 0, 1),
            RangeSetup(LibTypes.ParameterField.SponsorPercentFirst, 0, 100, 350),
            RangeSetup(LibTypes.ParameterField.SponsorPercent, 0, 100, 350),
            RangeSetup(LibTypes.ParameterField.Distribution, 0, 0, 0),
            RangeSetup(LibTypes.ParameterField.Distribution, 1, 10, 20),
            RangeSetup(LibTypes.ParameterField.Distribution, 2, 20, 30),
            RangeSetup(LibTypes.ParameterField.Distribution, 3, 20, 30),
            RangeSetup(LibTypes.ParameterField.Distribution, 4, 30, 40),
            RangeSetup(LibTypes.ParameterField.Distribution, 5, 30, 40),
            RangeSetup(LibTypes.ParameterField.Distribution, 6, 40, 50),
            RangeSetup(LibTypes.ParameterField.Distribution, 7, 40, 50),
            RangeSetup(LibTypes.ParameterField.Distribution, 8, 40, 50),
            RangeSetup(LibTypes.ParameterField.Distribution, 9, 30, 50),
            RangeSetup(LibTypes.ParameterField.Distribution, 10, 30, 50),
            RangeSetup(LibTypes.ParameterField.Distribution, 11, 30, 50),
            RangeSetup(LibTypes.ParameterField.Distribution, 12, 30, 50),
            RangeSetup(LibTypes.ParameterField.Distribution, 13, 30, 50),
            RangeSetup(LibTypes.ParameterField.Distribution, 14, 30, 50),
            RangeSetup(LibTypes.ParameterField.Distribution, 15, 0, 25),
            RangeSetup(LibTypes.ParameterField.Distribution, 16, 0, 25),
            RangeSetup(LibTypes.ParameterField.Distribution, 17, 0, 25),
            RangeSetup(LibTypes.ParameterField.Distribution, 18, 0, 25),
            RangeSetup(LibTypes.ParameterField.Distribution, 19, 0, 25),
            RangeSetup(LibTypes.ParameterField.Distribution, 20, 0, 25),
            RangeSetup(LibTypes.ParameterField.Distribution, 21, 0, 25),
            RangeSetup(LibTypes.ParameterField.AutoSellPeriods, 0, 60 days, 120 days),
            RangeSetup(LibTypes.ParameterField.AutoSellPeriods, 1, 60 days, 120 days),
            RangeSetup(LibTypes.ParameterField.AutoSellPeriods, 2, 60 days, 120 days),
            RangeSetup(LibTypes.ParameterField.AutoSellPeriods, 3, 60 days, 120 days)
        ];
        for (uint256 i = 0; i < setups.length; i++) {
            ranges[i] = _setRange(ps, setups[i].field, setups[i].index, setups[i].min, setups[i].max);
        }
        emit LibEvents.ParametersRanges(ranges);
    }

    function _setRangesNFT(LibTypes.RangesNFT[] memory nftRanges, LibTypes.NFT[] memory nfts) private {
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        for (uint256 i = 0; i < nftRanges.length; i++) {
            uint256 index = i + 1;
            _setRangeNFT(ps, LibTypes.NftField.Price, index, nftRanges[i].priceMin, nftRanges[i].priceMax);
            _setRangeNFT(ps, LibTypes.NftField.Limit, index, nftRanges[i].limitMin, nftRanges[i].limitMax);
            _setRangeNFT(ps, LibTypes.NftField.AutoBuys, index, nftRanges[i].autoBuysMin, nftRanges[i].autoBuysMax);
            _setRangeNFT(
                ps,
                LibTypes.NftField.FarmingTime,
                index,
                nftRanges[i].farmingTimeMin,
                nftRanges[i].farmingTimeMax
            );
            _setRangeNFT(
                ps,
                LibTypes.NftField.MiningTime,
                index,
                nftRanges[i].miningTimeMin,
                nftRanges[i].miningTimeMax
            );
            _setRangeNFT(
                ps,
                LibTypes.NftField.EarnLevels,
                index,
                nftRanges[i].earnLevelsMin,
                nftRanges[i].earnLevelsMax
            );
            emit LibEvents.NewNFT(index, nfts[i], nftRanges[i]);
        }
    }

    function _setRangeNFT(
        LibParametersStorage.ParametersStorage storage ps,
        LibTypes.NftField field,
        uint256 level,
        uint256 minVal,
        uint256 maxVal
    ) private {
        ps.minNftValues[field][level] = minVal;
        ps.maxNftValues[field][level] = maxVal;
    }

    function applyParameterUpdates(LibTypes.ParameterUpdate[] calldata updates) internal {
        for (uint256 i = 0; i < updates.length; i++) {
            _applyParameterUpdate(updates[i]);
        }
        _checkParameters();
        emit LibEvents.ParametersUpdated(updates);
    }

    function changeGiftNFT(uint32 level, LibTypes.GiftUpdate[] calldata updates) internal {
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        if (level == 0 || level >= ps.giftTypes.length) revert LibErrors.UnknownLevel();
        for (uint256 i = 0; i < updates.length; i++) {
            _updateGiftField(ps, level, updates[i]);
        }
        emit LibEvents.GiftUpdated(level, updates);
    }

    function changeNFT(uint256 level, LibTypes.NFTUpdate[] calldata updates) internal {
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        if (level == 0 || level >= ps.regularTypes.length) revert LibErrors.UnknownLevel();
        for (uint256 i = 0; i < updates.length; i++) {
            LibParametersLogic._applyNftUpdate(ps, level, updates[i]);
        }
        emit LibEvents.NftUpdated(level, updates);
    }

    function setDisabledStatus(uint32 level, bool isDisabled) internal {
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        ps.regularTypes[level].isDisabled = isDisabled;
        emit LibEvents.NftDisabledStatus(level, isDisabled);
    }

    function setFarmingPeriods(uint32 level, uint32[] memory periods) internal {
        if (periods.length > 2 || periods.length == 0) revert LibErrors.OutOfRange(periods.length, 1, 2);
        for (uint256 i; i < periods.length; i++) {
            if (periods[i] < 50 || periods[i] > 500) revert LibErrors.OutOfRange(periods[i], 50, 500);
        }
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        if (ps.regularTypes[level].periods.length == 0) revert LibErrors.OutOfRange(periods.length, 0, 0);
        ps.regularTypes[level].periods = periods;
        emit LibEvents.FarmingPeriodsUpdated(level, periods);
    }

    function setTxFeeRanges(uint256 min, uint256 max) internal {
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        ps.txFeeMin = min;
        ps.txFeeMax = max;
        emit LibEvents.TxFeeRangesChanged(min, max);
    }

    function getConstants() internal pure returns(LibTypes.Constants memory) {
        return LibTypes.Constants({
            denominator: LibConstants.DENOMINATOR,
            priceImpactEventDuration: LibConstants.PRICE_IMPACT_EVENT_DURATION,
            voucherDecayTime: LibConstants.VOUCHER_DECAY_TIME,
            voucherCutoffPeriod: LibConstants.VOUCHER_CUTOFF_PERIOD,
            freezeTime: LibConstants.FREEZE_TIME,
            unfreezeLimit: LibConstants.UNFREEZE_LIMIT,
            loanCutoffPeriod: LibConstants.LOAN_CUTOFF_PERIOD,
            sellAfterFee: LibConstants.SELL_AFTER_FEE,
            autosellAfterFee: LibConstants.AUTOSELL_AFTER_FEE,
            votesDecayTime: LibConstants.VOTES_DECAY_TIME,
            votesGracePeriod: LibConstants.VOTES_GRACE_PERIOD
        });
    }
}
