// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibTypes} from "./LibTypes.sol";

library LibErrors {
    error Reentrancy();
    // Parameters

    error WrongPercentageSum(LibTypes.PercentageError reason);
    error OutOfRange(uint256 value, uint256 min, uint256 max);
    error UnknownField();
    error UnknownLevel();

    // Resolver
    error LowLevel();
    error RestrictedLevel();
    error NotAnOwner();
    error GiftActive();
    error UserActive();
    error UserNotActive();
    error OutOfStock();
    error WrongType();
    error TooManyGifts();
    error VoucherExpired();
    error VoucherActive();

    // Tree

    error UserExists();

    // Marketing

    error UserNotExists();
    error NotEnoughBalance();
    error ArraySizeMismatch();
    error DeadlineExpired();
    error WrongPercentage();
    error EarlyToWithdraw();
    error NoReferal();
    error AccessRestricted();
    error TooHighLimitToRebought();
    error WrongValue();
    error WrongTxFee();
    error UserBanned();
    error UserSanctioned(address user);
    error TooEarly();
    error NoFreezes();

    // Vouchers
    error TooLateForSending();
    error ZeroValue();

    // Roles
    error MissingRole(bytes32);
    error OnlyDAO();

    // Farming

    error MiningInProcess();
    error MiningIsMissing();
    error FarmingInProcess();
    error EarlyToStart();
    error LateToStart();
    error NothingToClaim();
    error TokenSuspended();
    error AccumulationPeriodIsActive();
    error EmptyLimit();

    // Signature

    error WrongSignature();
    error SignatureReplay();
}
