// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibResolverStorage} from "../storage/LibResolverStorage.sol";
import {LibParametersStorage} from "../storage/LibParametersStorage.sol";
import {LibMarketingStorage} from "../storage/LibMarketingStorage.sol";
import {LibTreeStorage} from "../storage/LibTreeStorage.sol";
import {LibPaymentLogic} from "./LibPaymentLogic.sol";
import {LibTreeLogic} from "./LibTreeLogic.sol";
import {LibDiamond} from "./LibDiamond.sol";
import {LibTypes} from "./LibTypes.sol";
import {LibErrors} from "./LibErrors.sol";
import {LibEvents} from "./LibEvents.sol";
import {LibConstants} from "../libraries/LibConstants.sol";
import {IResolverFacet} from "../interfaces/IResolverFacet.sol";
import {IPaymentFacet} from "../interfaces/IPaymentFacet.sol";
import {LibResolverLogic} from "./LibResolverLogic.sol";
import {LibSignatureLogic} from "./LibSignatureLogic.sol";
import {LibFarmingLogic} from "../libraries/LibFarmingLogic.sol";

library LibMarketingLogic {
    /// asign id to user
    function createUser(address user) internal returns (uint64 userId) {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        if (ms.identity.userToId[user] == 0) {
            userId = ms.nextId++;
            ms.identity.userToId[user] = userId;
            ms.identity.idToUser[userId] = user;
        } else return ms.identity.userToId[user];
    }

    /// change autoBuy status
    function toggleAutoBuy() internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        uint64 userId = ms.identity.userToId[msg.sender];
        if (userId == 0) revert LibErrors.UserNotExists();
        ms.users[userId].autoBuyEnabled = !ms.users[userId].autoBuyEnabled;
        emit LibEvents.AutoBuyStatus(msg.sender, ms.users[userId].autoBuyEnabled);
    }

    /// register user in marketing tree structure
    function register(
        LibMarketingStorage.MarketingStorage storage ms,
        address user,
        uint64 sponsor,
        bool bypassSponsorCheck
    ) internal returns (uint64 userId) {
        userId = createUser(user);
        LibTreeLogic.registerUser(userId, sponsor, bypassSponsorCheck);
        ms.freezes[userId].push();
    }

    function tryUnfreeze() internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        uint64 userId = ms.identity.userToId[msg.sender];
        if (ms.freezes[userId].length == ms.lastResolvedFreezes[userId] + 1) revert LibErrors.NoFreezes();
        if (ms.users[userId].limit == 0) revert LibErrors.EmptyLimit();
        _unfreeze(ms, ps, userId);
    }

    /// user earnings
    function distributeToUser(
        LibMarketingStorage.MarketingStorage storage ms,
        LibParametersStorage.ParametersStorage storage ps,
        uint64 user,
        uint64 source,
        uint256 amount,
        uint32 deep,
        LibTypes.Action action,
        bool isDirect,
        bool autoBuy
    ) internal returns (uint256 toDistribute, uint256 fee) {
        LibTypes.DistributeToUserVars memory vars; // Fixing stack too deep
        if (ms.users[user].isBanned || user == 0) return (0, 0);
        vars.info = IResolverFacet(address(this)).getUserTokenInfo(user);
        vars.limit = ms.users[user].limit;
        while (vars.limit < amount) {
            if (ms.users[user].autoBuys == 0) break;
            uint256 addLimit = _tryAutoBuy(ms, ps, user, autoBuy);
            if (addLimit == 0) break;
            vars.limit += addLimit;
        }
        toDistribute = vars.limit > amount ? amount : vars.limit;
        fee = (toDistribute * ps.parameters.fee) / LibConstants.DENOMINATOR;
        toDistribute -= fee;
        vars.accumulativePercent = vars.info.typeNft == LibTypes.TypeNFT.REGULAR
            ? ps.parameters.accumulativePercent
            : vars.info.accumulativePercent;
        vars.amountAccumulative = (toDistribute * vars.accumulativePercent) / LibConstants.DENOMINATOR;
        vars.amountRegular = toDistribute - vars.amountAccumulative;
        LibPaymentLogic.updateBalance(
            user,
            source,
            vars.amountAccumulative,
            vars.amountRegular,
            fee,
            deep,
            true,
            action
        );
        ms.users[user].limit = vars.limit - toDistribute - fee;
        if (ms.users[user].limit == 0) LibFarmingLogic.terminate(ms.identity.idToUser[user]);
        vars.lost = amount - toDistribute - fee;
        if (vars.lost > 0 && !isDirect)
            emit LibEvents.LostProfit(ms.identity.idToUser[user], vars.lost, LibTypes.LostReason.LIMIT);
    }

    /// freeze exceeds from first direct sale
    function _freeze(
        LibMarketingStorage.MarketingStorage storage ms,
        LibParametersStorage.ParametersStorage storage ps,
        uint64 user,
        uint64 buyer,
        uint256 amount,
        bool autoBuy
    ) private {
        ms.freezes[user].push(
            LibTypes.Freeze({
                buyer: buyer,
                amount: amount,
                deadline: block.timestamp + LibConstants.FREEZE_TIME,
                autoBuy: autoBuy
            })
        );
        emit LibEvents.Frozen(
            ms.identity.idToUser[user],
            ms.identity.idToUser[buyer],
            amount,
            block.timestamp + LibConstants.FREEZE_TIME,
            ms.freezes[user].length - 1,
            autoBuy
        );
    }

    /// claim freeze after increasing limit
    function _unfreeze(
        LibMarketingStorage.MarketingStorage storage ms,
        LibParametersStorage.ParametersStorage storage ps,
        uint64 user
    ) private {
        uint256 limit = ms.users[user].limit;
        uint256 unfreezed;
        address userAddress = ms.identity.idToUser[user];
        bool finished = true;
        uint256 counter = 0;
        for (uint256 i = ms.lastResolvedFreezes[user] + 1; i < ms.freezes[user].length; i++) {
            if (counter == LibConstants.UNFREEZE_LIMIT) {
                ms.lastResolvedFreezes[user] = i - 1;
                finished = false;
                break;
            }
            LibTypes.Freeze storage freeze = ms.freezes[user][i];
            uint256 toUnfreeze = freeze.amount;
            address buyerAddress = ms.identity.idToUser[freeze.buyer];
            if (unfreezed + toUnfreeze > limit) {
                ms.lastResolvedFreezes[user] = i - 1;
                finished = false;
                if (limit > unfreezed) {
                    freeze.amount -= limit - unfreezed;
                    emit LibEvents.Unfrozen(userAddress, buyerAddress, limit - unfreezed, i, false, freeze.autoBuy);
                    unfreezed = limit;
                }
                break;
            } else {
                freeze.amount = 0;
                unfreezed += toUnfreeze;
                counter++;
                emit LibEvents.Unfrozen(userAddress, buyerAddress, toUnfreeze, i, true, freeze.autoBuy);
            }
        }
        if (finished) ms.lastResolvedFreezes[user] = ms.freezes[user].length - 1;
        ms.users[user].limit -= unfreezed;
        if (ms.users[user].limit == 0) LibFarmingLogic.terminate(ms.identity.idToUser[user]);
        uint256 fee = (unfreezed * ps.parameters.fee) / LibConstants.DENOMINATOR;
        uint256 toDistribute = unfreezed - fee;
        uint256 accumulative = (toDistribute * ps.parameters.accumulativePercent) / LibConstants.DENOMINATOR;
        LibPaymentLogic.toTokenReserve(ms, fee);
        LibPaymentLogic.updateBalance(
            user,
            0,
            accumulative,
            toDistribute - accumulative,
            fee,
            0,
            true,
            LibTypes.Action.UNFREEZE
        );
    }

    /// distribute sponsor earnings
    function _sponsorDistribute(
        LibMarketingStorage.MarketingStorage storage ms,
        LibParametersStorage.ParametersStorage storage ps,
        uint64 sponsor,
        uint64 buyer,
        uint256 amount,
        bool isFirst,
        bool autoBuy
    ) private returns (uint256 distributed, uint256 fee, uint256 toFreeze) {
        if (ms.users[sponsor].isBanned) return (0, 0, 0);
        (distributed, fee) = distributeToUser(
            ms,
            ps,
            sponsor,
            buyer,
            amount,
            0,
            LibTypes.Action.SPONSOR,
            true,
            autoBuy
        );
        uint256 undistributed = amount - distributed - fee;
        if (undistributed > 0) {
            if (isFirst || autoBuy) {
                toFreeze = undistributed;
                if (toFreeze > 0) _freeze(ms, ps, sponsor, buyer, toFreeze, autoBuy); // Теперь надо придумать, как нормально разграничить автобайный приход и нет
            } else {
                toFreeze = 0;
                emit LibEvents.LostProfit(ms.identity.idToUser[sponsor], undistributed, LibTypes.LostReason.LIMIT);
            }
        }
    }

    /// distribute matching bonuses
    function _matchingDistribute(
        LibMarketingStorage.MarketingStorage storage ms,
        LibParametersStorage.ParametersStorage storage ps,
        uint64 upper,
        uint64 buyer,
        uint256 amount,
        bool autoBuy
    )
        private
        returns (
            uint256[3] memory result // totalDistributed, toDevs, totalFee
        )
    {
        uint256 totalDistributed;
        uint256 toDevs;
        uint256 totalFee;
        uint32 matchingLevel = 0;
        while (true) {
            upper = LibTreeLogic.getSponsor(upper);
            if (upper == 0) break;
            LibTypes.UserTokenInfo memory info = IResolverFacet(address(this)).getUserTokenInfo(upper);
            if (ms.users[upper].isBanned) {
                continue;
            }
            uint256 matching = (amount * ps.parameters.matchingPercent) / LibConstants.DENOMINATOR;
            if (ms.users[upper].earnedByRef < ps.parameters.matchingThresholds[matchingLevel] || info.level < 4) {
                toDevs += matching;
                emit LibEvents.LostProfit(ms.identity.idToUser[upper], matching, LibTypes.LostReason.MATCHING);
            } else {
                (uint256 distributed, uint256 fee) = distributeToUser(
                    ms,
                    ps,
                    upper,
                    buyer,
                    matching,
                    matchingLevel + 1,
                    LibTypes.Action.MATCHING,
                    false,
                    autoBuy
                );
                totalDistributed += distributed;
                totalFee += fee;
            }
            matchingLevel++;
            if (matchingLevel == 3) break;
        }
        result[0] = totalDistributed;
        result[1] = toDevs;
        result[2] = totalFee;
        LibPaymentLogic.toDevs(ms, toDevs, LibTypes.Source.MATCHING);
    }

    /// distribute to upper users
    function _distributeTree(
        LibMarketingStorage.MarketingStorage storage ms,
        LibParametersStorage.ParametersStorage storage ps,
        uint64 buyer,
        uint256 amount,
        bool autoBuy
    ) private returns (LibTypes.TreeDistributionContext memory tree) {
        uint64[] memory upper = LibTreeLogic.getUpperUsers(buyer, 22);
        LibTypes.UserTokenInfo[] memory info = IResolverFacet(address(this)).getUsersTokenInfo(upper);
        uint8 level = 1;
        uint32 index;
        while (true) {
            if (index == 22) {
                upper = LibTreeLogic.getUpperUsers(upper[index - 1], 22);
                info = IResolverFacet(address(this)).getUsersTokenInfo(upper);
                index = 0;
            }
            if (upper[index] == 0 || level == 23) break;
            if (ms.users[upper[index]].isBanned) {
                index++;
                continue;
            }
            uint256 toDistribute = (amount * ps.parameters.distribution[level - 1]) / LibConstants.DENOMINATOR;
            if (toDistribute == 0) {
                index++;
                level++;
                continue;
            }

            if (ms.users[upper[index]].limit == 0) {
                if (_tryAutoBuy(ms, ps, upper[index], autoBuy) == 0) {
                    emit LibEvents.LostProfit(
                        ms.identity.idToUser[upper[index]],
                        toDistribute,
                        LibTypes.LostReason.LIMIT
                    );
                    index++;
                    continue;
                }
            }

            if (info[index].allowedDeep >= level) {
                (uint256 distributed, uint256 fee) = distributeToUser(
                    ms,
                    ps,
                    upper[index],
                    buyer,
                    toDistribute,
                    level,
                    LibTypes.Action.DISTRIBUTION,
                    false,
                    autoBuy
                );
                tree.fee += fee;
                tree.distributed += distributed;
                if (toDistribute - distributed - fee > 0)
                    emit LibEvents.LostProfit(
                        ms.identity.idToUser[upper[index]],
                        toDistribute - distributed - fee,
                        LibTypes.LostReason.LIMIT
                    );
            } else {
                emit LibEvents.LostProfit(ms.identity.idToUser[upper[index]], toDistribute, LibTypes.LostReason.DEEP);
            }
            index++;
            level++;
        }
        tree.undistributed =
            (amount * ps.parameters.totalDistributePercent) /
            LibConstants.DENOMINATOR -
            tree.distributed -
            tree.fee;
        LibPaymentLogic.toDevs(ms, tree.undistributed, LibTypes.Source.DISTRIBUTION);
    }

    /// distribute earnings from purchase
    function _processPurchase(
        LibMarketingStorage.MarketingStorage storage ms,
        LibParametersStorage.ParametersStorage storage ps,
        LibTypes.ProcessPurchaseArgs memory args
    ) private {
        LibTypes.UserTokenInfo memory info = IResolverFacet(address(this)).getUserTokenInfo(args.buyer);
        if (
            ms.users[args.buyer].limit > (info.limit * 300) / LibConstants.DENOMINATOR &&
            info.level == args.level &&
            !args.autoBuy &&
            !args.isUpgrade
        ) revert LibErrors.TooHighLimitToRebought();
        LibTypes.DistributionContext memory dc;
        uint64 sponsor = LibTreeLogic.getSponsor(args.buyer);

        if (!args.exists) {
            dc.toSponsor = (args.price * ps.parameters.sponsorPercentFirst) / LibConstants.DENOMINATOR;
            dc.toDevs = (args.price * ps.parameters.toDevsPercentFirst) / LibConstants.DENOMINATOR;
            dc.toTokenReserve += (args.price * ps.parameters.tokenReservePercentFirst) / LibConstants.DENOMINATOR;
        } else {
            dc.toSponsor = (args.price * ps.parameters.sponsorPercent) / LibConstants.DENOMINATOR;
            dc.toDevs = (args.price * ps.parameters.toDevsPercent) / LibConstants.DENOMINATOR;
            dc.toTokenReserve += (args.price * ps.parameters.tokenReservePercent) / LibConstants.DENOMINATOR;
        }

        emit LibEvents.TokenBought(
            ms.identity.idToUser[args.buyer],
            args.tokenId,
            args.level,
            ms.users[args.buyer].autoBuys,
            args.autoBuy
        );

        if (
            block.timestamp > ms.priceImpactStart &&
            block.timestamp < ms.priceImpactStart + LibConstants.PRICE_IMPACT_EVENT_DURATION
        ) {
            uint256 priceImpact = args.price - dc.toDevs - dc.toTokenReserve;
            ms.priceImpactBalance += priceImpact;
            emit LibEvents.PriceImpactEarnings(priceImpact);
        } else {
            (uint256 distributed, uint256 fee, uint256 toFreeze) = _sponsorDistribute(
                ms,
                ps,
                sponsor,
                args.buyer,
                dc.toSponsor,
                !args.exists,
                args.autoBuy
            );

            uint256[3] memory matchingResult = _matchingDistribute(
                ms,
                ps,
                sponsor,
                args.buyer,
                dc.toSponsor,
                args.autoBuy
            );

            LibTypes.TreeDistributionContext memory tree = _distributeTree(
                ms,
                ps,
                args.buyer,
                args.price,
                args.autoBuy
            );

            // Distributed to sponsor, tree and matching
            dc.totalDistributed += distributed + tree.distributed + matchingResult[0];

            // Total fee
            dc.toTokenReserve += fee + tree.fee + matchingResult[2];

            uint256 remainder = args.price -
                (dc.toDevs +
                    dc.toTokenReserve +
                    dc.totalDistributed +
                    toFreeze +
                    tree.undistributed +
                    matchingResult[1]);

            LibPaymentLogic.toDevs(ms, remainder, LibTypes.Source.UNDISTRIBUTED);
        }

        ms.users[sponsor].earnedByRef += args.price;
        ms.users[args.buyer].limit = args.limit;
        ms.users[args.buyer].lastAction = block.timestamp;

        if (!args.autoBuy && ms.freezes[args.buyer].length > ms.lastResolvedFreezes[args.buyer] + 1)
            _unfreeze(ms, ps, args.buyer);

        LibPaymentLogic.toDevs(ms, dc.toDevs, LibTypes.Source.DEVPERCENT);
        LibPaymentLogic.toTokenReserve(ms, dc.toTokenReserve);
        LibFarmingLogic.terminate(ms.identity.idToUser[args.buyer]);
        if (!args.autoBuy) emit LibEvents.AccumulativeBalanceTimerStarted(ms.identity.idToUser[args.buyer], block.timestamp);
    }

    /// ban or unban user
    function setBanStatus(address user, bool status) internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        uint64 userId = ms.identity.userToId[user];
        ms.users[userId].isBanned = status;
        emit LibEvents.UserBanStatus(user, status);
    }

    /// claim expired user freeze
    function _claimFreeze(
        LibMarketingStorage.MarketingStorage storage ms,
        LibParametersStorage.ParametersStorage storage ps,
        uint64 userId,
        uint256 index
    ) private {
        uint256 amount = ms.freezes[userId][index].amount;
        address userAddress = ms.identity.idToUser[userId];

        uint64 sponsor = LibTreeLogic.getSponsor(userId);
        uint256 toSponsor = (amount * ps.parameters.claimFrozenSponsorPercent) / LibConstants.DENOMINATOR;
        (uint256 distributed, uint256 fee) = distributeToUser(
            ms,
            ps,
            sponsor,
            userId,
            toSponsor,
            0,
            LibTypes.Action.SPONSOR_FREEZE_CLAIMED,
            false,
            false
        );
        uint256 remainder = toSponsor - distributed - fee;
        if (remainder > 0) {
            uint64 upper = LibTreeLogic.getSponsor(sponsor);
            if (upper != 0) {
                (uint256 upperDistributed, uint256 upperFee) = distributeToUser(
                    ms,
                    ps,
                    upper,
                    sponsor,
                    remainder,
                    0,
                    LibTypes.Action.SPONSOR_FREEZE_CLAIMED,
                    false,
                    false
                );
                remainder -= upperDistributed + upperFee;
                fee += upperFee;
            }
        }
        LibPaymentLogic.toTokenReserve(ms, amount - toSponsor + remainder + fee);
        emit LibEvents.LostProfit(userAddress, amount, LibTypes.LostReason.FROZEN);
        emit LibEvents.FreezeClaimed(userAddress, amount, index);
    }

    /// claim expired freezes from users
    function claimFreezes(address[] calldata usrs, uint256[] calldata amounts) internal {
        if (usrs.length != amounts.length) revert LibErrors.ArraySizeMismatch();
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();

        for (uint256 index; index < usrs.length; index++) {
            uint64 userId = ms.identity.userToId[usrs[index]];
            uint256 last = ms.lastResolvedFreezes[userId] + 1;
            uint256 counter = 0;
            for (uint256 i = last; i < ms.freezes[userId].length; i++) {
                if (counter == amounts[index]) break;
                if (ms.freezes[userId][last].deadline <= block.timestamp) {
                    _claimFreeze(ms, ps, userId, last);
                    last++;
                    counter++;
                } else break;
            }
            ms.lastResolvedFreezes[userId] = last - 1;
        }
    }

    /// buy new regular NFT
    function buyNFT(uint32 level, address referal, uint256[] memory vouchers) internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();

        if (level == 0 || level >= ps.regularTypes.length) revert LibErrors.UnknownLevel();

        if (ms.identity.userToId[referal] == 0) revert LibErrors.NoReferal();

        bool exists = LibTreeLogic.isUserExists(msg.sender);
        uint64 userId;

        if (!exists) userId = register(ms, msg.sender, ms.identity.userToId[referal], false);
        else userId = ms.identity.userToId[msg.sender];
        (uint256 tokenId, uint256 limit, uint256 price, uint256 autoBuys) = IResolverFacet(address(this))
            .processRegularBought(userId, level);
        bool canBuy = LibPaymentLogic.paymentForToken(ms, ps, userId, price, vouchers);
        if (!canBuy) revert LibErrors.NotEnoughBalance();
        ms.users[userId].autoBuys = autoBuys;

        _processPurchase(
            ms,
            ps,
            LibTypes.ProcessPurchaseArgs(
                tokenId,
                price,
                limit,
                userId,
                ms.identity.userToId[referal],
                level,
                exists,
                false,
                false
            )
        );
    }

    /// increase level of regular NFT
    function upgradeRegular(uint32 level, uint256[] memory vouchers) internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();

        if (level == 0 || level >= ps.regularTypes.length) revert LibErrors.UnknownLevel();

        uint64 userId = ms.identity.userToId[msg.sender];

        (uint256 tokenId, uint256 limit, uint256 price, uint256 autoBuys) = IResolverFacet(address(this))
            .processRegularUpgrade(userId, level);

        bool canBuy = LibPaymentLogic.paymentForToken(ms, ps, userId, price, vouchers);
        if (!canBuy) revert LibErrors.NotEnoughBalance();
        ms.users[userId].autoBuys = autoBuys;

        _processPurchase(
            ms,
            ps,
            LibTypes.ProcessPurchaseArgs(tokenId, price, limit, userId, 0, level, true, false, true)
        );
    }

    /// upgrade gift NFT to regular
    function upgradeGift(uint32 level, uint256[] memory vouchers) internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();

        if (level == 0 || level >= ps.regularTypes.length) revert LibErrors.UnknownLevel();

        uint64 userId = ms.identity.userToId[msg.sender];

        (uint256 tokenId, uint256 limit, uint256 price, uint256 autoBuys) = IResolverFacet(address(this))
            .processGiftUpgrade(userId, level);

        bool canBuy = LibPaymentLogic.paymentForToken(ms, ps, userId, price, vouchers);
        if (!canBuy) revert LibErrors.NotEnoughBalance();
        ms.users[userId].autoBuys = autoBuys;

        _processPurchase(
            ms,
            ps,
            LibTypes.ProcessPurchaseArgs(tokenId, price, limit, userId, 0, level, true, false, true)
        );
    }

    /// rebuy current NFT
    function reBuy(uint256[] memory vouchers) internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();

        uint64 userId = ms.identity.userToId[msg.sender];
        uint256 tokenId = rs.owners[userId];

        if (tokenId == 0) revert LibErrors.UserNotActive();
        LibTypes.UserTokenInfo memory buyerInfo = IResolverFacet(address(this)).getUserTokenInfo(userId);

        if (buyerInfo.isDisabled) revert LibErrors.RestrictedLevel();
        bool canBuy = LibPaymentLogic.paymentForToken(ms, ps, userId, buyerInfo.price, vouchers);
        if (!canBuy) revert LibErrors.NotEnoughBalance();
        _processPurchase(
            ms,
            ps,
            LibTypes.ProcessPurchaseArgs(
                tokenId,
                buyerInfo.price,
                buyerInfo.limit,
                userId,
                0,
                buyerInfo.level,
                true,
                false,
                false
            )
        );
    }

    /// try to rebuy current token
    function _tryAutoBuy(
        LibMarketingStorage.MarketingStorage storage ms,
        LibParametersStorage.ParametersStorage storage ps,
        uint64 userId,
        bool autoBuy
    ) private returns (uint256 limit) {
        LibTypes.UserTokenInfo memory buyerInfo = IResolverFacet(address(this)).getUserTokenInfo(userId);
        if (!autoBuy && ms.users[userId].autoBuys > 0 && ms.users[userId].autoBuyEnabled && !buyerInfo.isDisabled) {
            bool canBuy = LibPaymentLogic.paymentForToken(ms, ps, userId, buyerInfo.price, new uint256[](0));
            if (canBuy) {
                ms.users[userId].autoBuys--;
                _processPurchase(
                    ms,
                    ps,
                    LibTypes.ProcessPurchaseArgs(
                        buyerInfo.tokenId,
                        buyerInfo.price,
                        buyerInfo.limit,
                        userId,
                        0,
                        buyerInfo.level,
                        true,
                        true,
                        false
                    )
                );
                limit = buyerInfo.limit;
            } else limit = 0;
        }
    }

    /// change asigned to id address
    function changeWallet(address newOwner, address oldOwner) internal {
        LibResolverLogic.changeUserAddress(newOwner, oldOwner);
        emit LibEvents.WalletAddressSwapped(oldOwner, newOwner);
    }

    /// sell full structure
    function sellBusiness(address newOwner, uint256 nonce, bytes calldata signature) internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();

        if (!ps.parameters.businessSale) revert LibErrors.AccessRestricted();
        bytes32 structHash = keccak256(
            abi.encode(LibSignatureLogic.SELL_BUSINESS_REQUEST_TYPEHASH, msg.sender, newOwner, nonce)
        );
        LibSignatureLogic.verify(structHash, signature);
        uint64 userId = ms.identity.userToId[msg.sender];
        uint256 fee = ps.parameters.businessSaleFee;
        if (ms.users[userId].balance < fee) revert LibErrors.NotEnoughBalance();
        LibPaymentLogic.updateBalance(userId, 0, 0, fee, 0, 0, false, LibTypes.Action.BUSINESS_SALE);
        LibPaymentLogic.toTokenReserve(ms, fee);

        LibResolverLogic.changeUserAddress(newOwner, msg.sender);
        emit LibEvents.BusinessSold(msg.sender, newOwner);
    }

    /// start event for increasing DA price
    function startPriceImpactEvent(uint256 timestamp) internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        ms.priceImpactStart = timestamp;
        emit LibEvents.PriceImpactEvent(timestamp);
    }

    /// send eargings for event to TR
    function proceedPriceImpactEarnings() internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        if (ms.priceImpactStart + LibConstants.PRICE_IMPACT_EVENT_DURATION > block.timestamp)
            revert LibErrors.TooEarly();
        if (ms.priceImpactBalance == 0) revert LibErrors.NotEnoughBalance();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.contracts.tokenReserve.depositWithClaim(ms.priceImpactBalance);
        emit LibEvents.PriceImpactEventEnd(ms.priceImpactBalance);
        ms.priceImpactBalance = 0;
    }
}
