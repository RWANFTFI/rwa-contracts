// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAdminContract} from "../../interfaces/IAdminContract.sol";
import {IVoucher} from "../../interfaces/IVoucher.sol";
import {INFT} from "../../interfaces/INFT.sol";
import {IGiftNFT} from "../../interfaces/IGiftNFT.sol";
import {ITokenReserve} from "../../interfaces/ITokenReserve.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

library LibTypes {
    struct Contracts {
        IERC20 paymentToken;
        IAdminContract adminContract;
        INFT regularContract;
        INFT ambContract;
        IGiftNFT giftContract;
        IVoucher voucherContract;
        ITokenReserve tokenReserve;
        address dao;
    }

    struct Constants {
        uint256 denominator;
        uint256 priceImpactEventDuration;
        uint256 voucherDecayTime;
        uint256 voucherCutoffPeriod;
        uint256 unfreezeLimit;
        uint256 freezeTime;
        uint256 loanCutoffPeriod;
        uint256 sellAfterFee;
        uint256 autosellAfterFee;
        uint256 votesDecayTime;
        uint256 votesGracePeriod;
    }

    // Parameters

    enum PercentageError {
        AccumulativeClaimDistribute,
        TotalDistributePercent,
        TreeDistributePercent
    }

    enum ParameterField {
        AccumulativeTransferFee,
        AccumulativePercent,
        AccumulativeUseFee,
        SponsorPercentFirst,
        SponsorPercent,
        TokenReservePercentFirst,
        TokenReservePercent,
        ToDevsPercentFirst,
        ToDevsPercent,
        Fee,
        LoanFee,
        WithdrawalFee,
        GiftPrice,
        ClaimFrozenSponsorPercent,
        BusinessSaleFee,
        AccumulativeDecayTime,
        DecayTimeNFTM,
        TotalDistributePercent,
        GiftHoldLimit,
        BusinessSale,
        MatchingThreshold,
        AccumulativeClaimDistributeSponsor,
        AccumulativeClaimDistributeCompany,
        AccumulativeClaimDistributeTokenReserve,
        AccumulativeClaimDistributeGiftSponsor,
        AccumulativeClaimDistributeGiftCompany,
        AccumulativeClaimDistributeGiftTokenReserve,
        Distribution,
        AutoSellPeriods
    }

    enum NftField {
        Price,
        Limit,
        AutoBuys,
        FarmingTime,
        MiningTime,
        EarnLevels
    }

    enum GiftField {
        Price,
        Limit,
        Supply
    }

    struct ParameterUpdate {
        ParameterField field;
        uint256 index;
        uint256 value;
    }

    struct ParameterRange {
        ParameterField field;
        uint256 index;
        uint256 min;
        uint256 max;
    }

    struct NFTUpdate {
        NftField field;
        uint256 value;
    }

    struct GiftUpdate {
        GiftField field;
        uint256 value;
    }

    struct Parameters {
        uint256 accumulativeTransferFee;
        uint256 accumulativePercent;
        uint256 accumulativeUseFee;
        uint256 sponsorPercentFirst;
        uint256 sponsorPercent;
        uint256 tokenReservePercentFirst;
        uint256 tokenReservePercent;
        uint256 toDevsPercentFirst;
        uint256 toDevsPercent;
        uint256 matchingPercent;
        uint256 fee;
        uint256 loanFee;
        uint256 withdrawalFee;
        uint256 giftPrice;
        uint256 claimFrozenSponsorPercent;
        uint256 businessSaleFee;
        uint32 accumulativeDecayTime;
        uint32 decayTimeNFTM;
        uint16 totalDistributePercent;
        uint16 giftHoldLimit;
        bool businessSale;
        uint80[3] matchingThresholds;
        uint16[3] accumulativeClaimDistribute;
        uint16[3] accumulativeClaimDistributeGift;
        uint8[22] distribution;
        uint24[4] autoSellPeriods;
    }

    struct NFT {
        uint256 price;
        uint256 limit;
        uint256 supply;
        uint64 unlocksAfter;
        uint32 autoBuys;
        uint32 earnLevels;
        uint32 farmingTime;
        uint32 miningTime;
        uint32 level;
        bool isDisabled;
        uint32[] periods;
    }

    struct RangesNFT {
        uint256 priceMin;
        uint256 priceMax;
        uint256 limitMin;
        uint256 limitMax;
        uint256 autoBuysMin;
        uint256 autoBuysMax;
        uint256 farmingTimeMin;
        uint256 farmingTimeMax;
        uint256 miningTimeMin;
        uint256 miningTimeMax;
        uint256 earnLevelsMin;
        uint256 earnLevelsMax;
    }

    struct GiftNFT {
        uint256 price;
        uint256 limit;
        uint256 supply;
        uint256 accumulativePercent;
        uint32 earnLevels;
        uint32 level;
        uint32 allowedUpgradeLevel;
    }

    struct RangesGift {
        uint256 priceMin;
        uint256 priceMax;
        uint256 limitMin;
        uint256 limitMax;
    }

    // Resolver

    enum TypeNFT {
        NONE,
        REGULAR,
        GIFT
    }

    struct GiftRecipient {
        address recipient;
        uint256 amount;
    }

    struct GiftToMint {
        uint32 level;
        GiftRecipient[] recipients;
    }

    struct RegisteredNFT {
        uint64 owner;
        uint32 level;
        TypeNFT typeNFT;
        bool isActive;
    }

    struct UserTokenInfo {
        uint256 tokenId;
        uint256 accumulativePercent;
        uint256 price;
        uint256 limit;
        uint32 autoBuys;
        uint32 allowedDeep;
        uint32 level;
        TypeNFT typeNft;
        bool isDisabled;
        uint32[] periods;
        uint32 farmingTime;
        uint32 miningTime;
    }

    struct Voucher {
        uint256 value;
        uint256 timestamp;
    }

    // Tree

    struct Tree {
        uint64 up;
        uint64 left;
        uint64 right;
        uint64 sponsor;
        bool active;
    }

    // Marketing

    enum Action {
        DISTRIBUTION,
        MATCHING,
        SPONSOR,
        PURCHASE,
        TRANSFER,
        UNFREEZE,
        GIFT,
        WITHDRAW,
        BUSINESS_SALE,
        VOUCHER,
        REPAY,
        SPONSOR_ACCUMULATIVE_CLAIMED,
        SPONSOR_FREEZE_CLAIMED
    }

    enum Source {
        DISTRIBUTION,
        MATCHING,
        UNDISTRIBUTED,
        WITHDRAW,
        DEVPERCENT
    }

    enum LostReason {
        DEEP,
        LIMIT,
        FROZEN,
        ACCUMULATIVE,
        MATCHING,
        DA_LIMIT
    }

    enum BuyAction {
        PURCHASE,
        UPGRADE_GIFT
    }

    struct User {
        uint256 balance;
        uint256 accumulativeBalance;
        uint256 tokenId;
        uint256 limit;
        uint256 earnedByRef;
        uint256 autoBuys;
        uint256 lastAction;
        bool autoBuyEnabled;
        bool isBanned;
    }

    struct Freeze {
        uint64 buyer;
        uint256 amount;
        uint256 deadline;
        bool autoBuy;
    }

    struct UserId {
        mapping(address => uint64) userToId;
        mapping(uint64 => address) idToUser;
    }

    struct BalanceUpdate {
        address user;
        uint256 amountaccumulative;
        uint256 amount;
    }

    struct Buy {
        uint256 tokenId;
        uint256 level;
    }

    struct PlaceUser {
        address up;
        bool isLeft;
        bool toBePlaced;
    }

    struct DistributionContext {
        uint256 toTokenReserve;
        uint256 toSponsor;
        uint256 toDevs;
        uint256 totalDistributed;
    }

    struct TreeDistributionContext {
        uint256 distributed;
        uint256 fee;
        uint256 undistributed;
    }

    struct ProcessPurchaseArgs {
        uint256 tokenId;
        uint256 price;
        uint256 limit;
        uint64 buyer;
        uint64 referal;
        uint32 level;
        bool exists;
        bool autoBuy;
        bool isUpgrade;
    }

    struct DistributeToUserVars {
        uint256 limit;
        uint256 toDistribute;
        uint256 fee;
        uint256 accumulativePercent;
        uint256 amountAccumulative;
        uint256 amountRegular;
        uint256 lost;
        UserTokenInfo info;
    }

    // Farming
    
    struct Mining {
        uint256 endTime;
        uint256 reward;
        uint256 tokenId;
        uint256 period;
        bool isActive;
    }   

    struct Farming {
        uint256 endTime;
        bool isActive;
    }
}
