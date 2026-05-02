// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibTypes} from "./LibTypes.sol";

library LibEvents {
    event NewDAO(address dao);

    // Parameters

    event InitialParameters(LibTypes.Parameters params, LibTypes.Constants constants);
    event ParametersRanges(LibTypes.ParameterRange[55] ranges);
    event ParametersUpdated(LibTypes.ParameterUpdate[] updates);
    event NewNFT(uint256 index, LibTypes.NFT nft, LibTypes.RangesNFT ranges);
    event NftUpdated(uint256 level, LibTypes.NFTUpdate[] updates);
    event NftDisabledStatus(uint32 level, bool isDisabled);
    event NewGiftNFT(uint256 index, LibTypes.GiftNFT nft, LibTypes.RangesGift ranges);
    event GiftUpdated(uint32 level, LibTypes.GiftUpdate[] updates);
    event FarmingPeriodsUpdated(uint32 level, uint32[] periods);
    event TxFeeRangesChanged(uint256 min, uint256 max);
    event TxFeeChanged(uint256 fee);

    // Resolver

    event GiftGranted(address user, uint256 tokenId, uint256 level);
    event AmbassadorGranted(address indexed user, uint256 tokenId);
    event AmbassadorRevoked(address indexed user, uint256 tokenId);
    event GiftActivated(address user, uint256 tokenId);
    
    // Voucher

    event NewVoucher(address user, uint256 tokenId, uint256 price, uint256 timestamp);
    event VoucherValueReduced(uint256 tokenId, uint256 newValue);

    // Tree

    event UserPlaced(address indexed user, address sponsor, address up, bool isLeft);

    // Marketing

    event BalanceUpdated(
        address indexed user,
        address indexed source,
        uint256 accumulativeBalance,
        uint256 balance,
        uint256 fee,
        uint32 level,
        bool isAdd,
        LibTypes.Action action
    );
    event TokenReserveReplenishment(uint256 amount);
    event DevBalanceReplenishment(uint256 amount, LibTypes.Source source);
    event TokenBought(address indexed user, uint256 tokenId, uint256 level, uint256 autoBuys, bool autoBuy);
    event Frozen(address indexed user, address buyer, uint256 amount, uint256 deadline, uint256 index, bool autoBuy);
    event Unfrozen(address indexed user, address buyer, uint256 amount, uint256 index, bool resolved, bool autoBuy);
    event FreezeClaimed(address indexed user, uint256 amount, uint256 index);
    event Deposit(address indexed user, uint256 amount, string source);
    event Withdraw(address indexed user, uint256 amount, uint256 fee);
    event LostProfit(address indexed user, uint256 amount, LibTypes.LostReason reason);
    event AutoBuyStatus(address indexed user, bool status);
    event BusinessSold(address indexed oldOwner, address indexed newOwner);
    event WalletAddressSwapped(address indexed oldOwner, address indexed newOwner);
    event UserBanStatus(address indexed user, bool isBanned);
    event TokenReserveClaimed(uint256 amount);
    event DevBalanceClaimed(uint256 amount);
    event AccumulativeTransfer(address indexed from, address indexed to, uint256 amount, uint256 fee);
    event LimitReduced(address indexed user, uint256 amount, uint256 fee, string descripion);
    event AccumulativeBalanceTimerStarted(address indexed user, uint256 timestamp);
    event PriceImpactEvent(uint256 startTime);
    event PriceImpactEventEnd(uint256 usdtAmount);
    event PriceImpactEarnings(uint256 amount);

    // Farming
    event MiningStarted(address indexed user, uint256 indexed tokenId, uint256 endTime, uint256 reward, uint256 period);
    event FarmingStarted(address indexed user, uint256 indexed tokenId, uint256 endTime, uint256 reward, uint256 period);
    event Terminated(address indexed user, uint256 indexed tokenId, uint256 timestamp);
    event Claimed(address indexed user, uint256 indexed tokenId, uint256 claimed, uint256 price);
    event TokenSuspensionStatusChanged(uint256 indexed tokenId, bool status);
    event AccumulationEventStart(uint256 startTime, uint256 endTime);
    event AccumulationEventInterrupted();

    // Signature
    event SignatureVerificationStatus(bool status);
}
