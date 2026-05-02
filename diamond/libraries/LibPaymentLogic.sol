// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {LibResolverStorage} from "../storage/LibResolverStorage.sol";
import {LibParametersStorage} from "../storage/LibParametersStorage.sol";
import {LibMarketingStorage} from "../storage/LibMarketingStorage.sol";
import {IMarketingFacet} from "../interfaces/IMarketingFacet.sol";
import {LibDiamond} from "./LibDiamond.sol";
import {LibConstants} from "./LibConstants.sol";
import {LibSignatureLogic} from "./LibSignatureLogic.sol";
import {LibResolverLogic} from "./LibResolverLogic.sol";
import {LibTypes} from "./LibTypes.sol";
import {LibErrors} from "./LibErrors.sol";
import {LibEvents} from "./LibEvents.sol";
import {LibTreeLogic} from "./LibTreeLogic.sol";
import {LibMarketingLogic} from "./LibMarketingLogic.sol";
import {LibFarmingLogic} from "./LibFarmingLogic.sol";
import {LibVoucherLogic} from "./LibVoucherLogic.sol";

library LibPaymentLogic {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    function deposit(uint256 amount) internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        uint64 userId = LibMarketingLogic.createUser(msg.sender);
        ds.contracts.paymentToken.safeTransferFrom(msg.sender, address(this), amount);
        ms.users[userId].balance += amount;
        emit LibEvents.Deposit(msg.sender, amount, block.chainid.toString());
    }

    function withdraw(uint256 amount, uint256 nonce, bytes calldata signature) internal {
        bytes32 structHash = keccak256(
            abi.encode(LibSignatureLogic.WITHDRAW_REQUEST_TYPEHASH, msg.sender, amount, nonce)
        );
        LibSignatureLogic.verify(structHash, signature);

        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        if (amount > ms.users[ms.identity.userToId[msg.sender]].balance) revert LibErrors.NotEnoughBalance();
        uint256 fee = (amount * ps.parameters.withdrawalFee) / LibConstants.DENOMINATOR;
        ms.users[ms.identity.userToId[msg.sender]].balance -= amount;
        ds.contracts.paymentToken.safeTransfer(msg.sender, amount - fee);
        toTokenReserve(ms, fee);
        emit LibEvents.Withdraw(msg.sender, amount, fee);
    }

    function transferAccumulative(
        address to,
        uint256 amount,
        uint256 deadline,
        uint256 nonce,
        bytes calldata signature
    ) internal {
        if (block.timestamp > deadline) revert LibErrors.DeadlineExpired();

        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();

        LibTypes.User storage recipient = ms.users[ms.identity.userToId[to]];
        uint64 senderId = ms.identity.userToId[msg.sender];

        if (ms.identity.userToId[to] == 0) revert LibErrors.UserNotExists();
        LibTypes.UserTokenInfo memory info = LibResolverLogic.getUserTokenInfo(senderId);
        if (info.typeNft == LibTypes.TypeNFT.GIFT) revert LibErrors.AccessRestricted();

        bytes32 structHash = keccak256(
            abi.encode(
                LibSignatureLogic.TRANSFER_ACCUMULATIVE_REQUEST_TYPEHASH,
                msg.sender,
                to,
                amount,
                deadline,
                nonce
            )
        );
        LibSignatureLogic.verify(structHash, signature);

        uint256 fee = (amount * ps.parameters.accumulativeTransferFee) / LibConstants.DENOMINATOR;
        if (ms.users[senderId].accumulativeBalance < amount + fee) revert LibErrors.NotEnoughBalance();
        ms.users[senderId].accumulativeBalance -= amount + fee;
        if (recipient.accumulativeBalance == 0) {
            recipient.lastAction = block.timestamp;
            emit LibEvents.AccumulativeBalanceTimerStarted(to, block.timestamp);
        }
        recipient.accumulativeBalance += amount;
        toTokenReserve(ms, fee);
        emit LibEvents.BalanceUpdated(msg.sender, address(0), amount + fee, 0, fee, 0, false, LibTypes.Action.TRANSFER);
        emit LibEvents.BalanceUpdated(to, msg.sender, amount, 0, 0, 0, true, LibTypes.Action.TRANSFER);
        emit LibEvents.AccumulativeTransfer(msg.sender, to, amount, fee);
    }

    function paymentForGiftTransfer(address user) internal {
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        uint64 userId = ms.identity.userToId[user];
        if (ms.users[userId].balance < ps.parameters.giftPrice) revert LibErrors.NotEnoughBalance();
        _updateBalance(ms, userId, 0, 0, ps.parameters.giftPrice, 0, 0, false, LibTypes.Action.GIFT);
        toTokenReserve(ms, ps.parameters.giftPrice);
    }

    function paymentForToken(
        LibMarketingStorage.MarketingStorage storage ms,
        LibParametersStorage.ParametersStorage storage ps,
        uint64 buyer,
        uint256 price,
        uint256[] memory vouchers
    ) internal returns (bool canBuy) {
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();
        uint256 priceAccumulative;
        uint256 priceRegular = price;
        uint256 fee;
        if (vouchers.length != 0) {
            for (uint256 i; i < vouchers.length; i++) {
                uint256 voucherValue = rs.vouchers[vouchers[i]].value;
                if (voucherValue > priceRegular) {
                    LibVoucherLogic.reduceVoucherValue(vouchers[i], priceRegular);
                    priceRegular = 0;
                    break;
                } else {
                    priceRegular -= voucherValue;
                    LibVoucherLogic.useVoucher(vouchers[i]);
                }
            }
            canBuy = ms.users[buyer].balance >= priceRegular;
        } else {
            (canBuy, priceAccumulative, priceRegular, fee) = paymentCapability(ps, ms.users[buyer], price);
        }
        if (!canBuy) return false;
        updateBalance(buyer, 0, priceAccumulative, priceRegular, fee, 0, false, LibTypes.Action.PURCHASE);
        toTokenReserve(ms, fee);
    }

    function toTokenReserve(LibMarketingStorage.MarketingStorage storage ms, uint256 amount) internal {
        if (amount > 0) {
            ms.tokenReserveBalance += amount;
            emit LibEvents.TokenReserveReplenishment(amount);
        }
    }

    function paymentCapability(
        LibParametersStorage.ParametersStorage storage ps,
        LibTypes.User memory buyer,
        uint256 price
    ) internal view returns (bool canBuy, uint256 priceAccumulative, uint256 priceRegular, uint256 fee) {
        uint256 maxCoverByAccumulative = (buyer.accumulativeBalance *
            (LibConstants.DENOMINATOR - ps.parameters.accumulativeUseFee)) / LibConstants.DENOMINATOR;

        if (price <= maxCoverByAccumulative) {
            priceAccumulative =
                (price * LibConstants.DENOMINATOR) /
                (LibConstants.DENOMINATOR - ps.parameters.accumulativeUseFee);
            priceRegular = 0;
            canBuy = true;
        } else {
            priceAccumulative = buyer.accumulativeBalance;
            uint256 covered = (priceAccumulative * (LibConstants.DENOMINATOR - ps.parameters.accumulativeUseFee)) /
                LibConstants.DENOMINATOR;
            uint256 remaining = price - covered;
            canBuy = buyer.balance >= remaining;
            priceRegular = remaining;
        }
        fee = (priceAccumulative * ps.parameters.accumulativeUseFee) / LibConstants.DENOMINATOR;
    }

    function updateBalance(
        uint64 user,
        uint64 source,
        uint256 accumulativeBalance,
        uint256 balance,
        uint256 fee,
        uint32 level,
        bool isAdd,
        LibTypes.Action action
    ) internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        _updateBalance(ms, user, source, accumulativeBalance, balance, fee, level, isAdd, action);
    }

    function _updateBalance(
        LibMarketingStorage.MarketingStorage storage ms,
        uint64 user,
        uint64 source,
        uint256 accumulativeBalance,
        uint256 balance,
        uint256 fee,
        uint32 level,
        bool isAdd,
        LibTypes.Action action
    ) private {
        if (isAdd) {
            if (ms.users[user].accumulativeBalance == 0 && accumulativeBalance > 0) {
                ms.users[user].lastAction = block.timestamp;
                emit LibEvents.AccumulativeBalanceTimerStarted(ms.identity.idToUser[user], block.timestamp);
            }
            ms.users[user].accumulativeBalance += accumulativeBalance;
            ms.users[user].balance += balance;
        } else {
            ms.users[user].accumulativeBalance -= accumulativeBalance;
            ms.users[user].balance -= balance;
        }
        if (accumulativeBalance > 0 || balance > 0)
            emit LibEvents.BalanceUpdated(
                ms.identity.idToUser[user],
                ms.identity.idToUser[source],
                accumulativeBalance,
                balance,
                fee,
                level,
                isAdd,
                action
            );
    }

    function toDevs(LibMarketingStorage.MarketingStorage storage ms, uint256 amount, LibTypes.Source source) internal {
        if (amount > 0) {
            ms.devBalance += amount;
            emit LibEvents.DevBalanceReplenishment(amount, source);
        }
    }

    function reduceLimit(
        address user,
        uint256 amount,
        bool deductFee,
        string memory description
    ) internal returns (uint256 paid) {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();

        uint64 userId = ms.identity.userToId[user];
        if (userId == 0) return 0;
        uint256 limit = ms.users[userId].limit;
        paid = limit >= amount ? amount : limit;
        uint256 fee = deductFee ? (paid * ps.parameters.fee) / LibConstants.DENOMINATOR : 0;
        ms.users[userId].limit -= paid;
        ms.users[userId].balance += paid - fee;
        if (ms.users[userId].limit == 0) LibFarmingLogic.terminate(user);
        if (paid < amount) emit LibEvents.LostProfit(user, amount - paid, LibTypes.LostReason.DA_LIMIT);
        if (paid > 0) {
            toTokenReserve(ms, fee);
            ds.contracts.paymentToken.safeTransferFrom(msg.sender, address(this), paid);
            emit LibEvents.LimitReduced(user, paid - fee, fee, description);
        }
    }

    function withdrawAccumulative(address user) internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();

        uint64 userId = ms.identity.userToId[user];
        if (ms.users[userId].lastAction + ps.parameters.accumulativeDecayTime > block.timestamp)
            revert LibErrors.EarlyToWithdraw();
        uint256 balance = ms.users[userId].accumulativeBalance;
        if (balance == 0) revert LibErrors.NotEnoughBalance();
        LibTypes.UserTokenInfo memory info = LibResolverLogic.getUserTokenInfo(userId);
        uint64 sponsor = LibTreeLogic.getSponsor(userId);
        uint256 toDevelopers;
        uint256 toSponsor;
        if (info.typeNft == LibTypes.TypeNFT.REGULAR) {
            toDevelopers = (balance * ps.parameters.accumulativeClaimDistribute[1]) / LibConstants.DENOMINATOR;
            toSponsor = (balance * ps.parameters.accumulativeClaimDistribute[0]) / LibConstants.DENOMINATOR;
        } else {
            toDevelopers = (balance * ps.parameters.accumulativeClaimDistributeGift[1]) / LibConstants.DENOMINATOR;
            toSponsor = (balance * ps.parameters.accumulativeClaimDistributeGift[0]) / LibConstants.DENOMINATOR;
        }
        uint256 toTR = balance - toDevelopers - toSponsor;
        updateBalance(userId, 0, balance, 0, 0, 0, false, LibTypes.Action.WITHDRAW);
        (uint256 distributed, uint256 fee) = LibMarketingLogic.distributeToUser(
            ms,
            ps,
            sponsor,
            userId,
            toSponsor,
            0,
            LibTypes.Action.SPONSOR_ACCUMULATIVE_CLAIMED,
            false,
            false
        );
        uint256 remainder = toSponsor - distributed - fee;
        if (remainder > 0) {
            uint64 upper = LibTreeLogic.getSponsor(sponsor);
            if (upper != 0) {
                (uint256 upperDistributed, uint256 upperFee) = LibMarketingLogic.distributeToUser(
                    ms,
                    ps,
                    upper,
                    userId,
                    remainder,
                    0,
                    LibTypes.Action.SPONSOR_ACCUMULATIVE_CLAIMED,
                    false,
                    false
                );
                remainder -= upperDistributed + upperFee;
                fee += upperFee;
            }
        }
        toTokenReserve(ms, remainder + fee + toTR);
        emit LibEvents.LostProfit(user, balance, LibTypes.LostReason.ACCUMULATIVE);
        toDevs(ms, toDevelopers, LibTypes.Source.WITHDRAW);
    }

    function claim(uint256 amount, bool isTokenReserve) internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (isTokenReserve) {
            if (ms.tokenReserveBalance < amount) revert LibErrors.NotEnoughBalance();
            ms.tokenReserveBalance -= amount;
            emit LibEvents.TokenReserveClaimed(amount);
        } else {
            if (ms.devBalance < amount) revert LibErrors.NotEnoughBalance();
            ms.devBalance -= amount;
            emit LibEvents.DevBalanceClaimed(amount);
        }
        ds.contracts.paymentToken.safeTransfer(ms.holder, amount);
    }

    function setTxFee(uint256 fee) internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();

        if (fee > ps.txFeeMax || fee < ps.txFeeMin) revert LibErrors.WrongTxFee();
        ms.txFee = fee;
        emit LibEvents.TxFeeChanged(fee);
    }

    function depositToUser(address user, uint256 amount, string memory source) internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        uint64 userId = LibMarketingLogic.createUser(user);
        ds.contracts.paymentToken.safeTransferFrom(msg.sender, address(this), amount);
        ms.users[userId].balance += amount;
        emit LibEvents.Deposit(user, amount, source);
    }

    function depositToTokenReserve(uint256 amount) internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        ds.contracts.paymentToken.safeTransferFrom(msg.sender, address(this), amount);
        toTokenReserve(ms, amount);
    }

    function buyVoucher(uint256 price) internal {
        if (price == 0) revert LibErrors.ZeroValue();
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        uint64 userId = ms.identity.userToId[msg.sender];
        if (ms.users[userId].balance < price) revert LibErrors.NotEnoughBalance();
        _updateBalance(ms, userId, 0, 0, price, 0, 0, false, LibTypes.Action.VOUCHER);
        LibVoucherLogic.createVoucher(price);
    }

    function changeHolder(address holder) internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        ms.holder = holder;
    }

    function takePayment(address user, uint256 amount) internal {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint64 userId = ms.identity.userToId[user];
        LibTypes.User storage userStruct = ms.users[userId];
        if (userStruct.balance < amount) revert LibErrors.NotEnoughBalance();
        _updateBalance(ms, userId, 0, 0, amount, 0, 0, false, LibTypes.Action.REPAY);
        ds.contracts.paymentToken.safeTransfer(address(ds.contracts.tokenReserve), amount);
    }
}
