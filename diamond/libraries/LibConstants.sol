// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library LibConstants {
    bytes32 public constant SECURED_ROLE = keccak256("SECURED_ROLE");
    bytes32 public constant SERVICE_ROLE = keccak256("SERVICE_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public constant DENOMINATOR = 1000;
    uint256 public constant FREEZE_TIME = 72 hours;
    uint256 public constant PRICE_IMPACT_EVENT_DURATION = 24 hours;
    uint256 public constant VOUCHER_DECAY_TIME = 365 days;
    uint256 public constant VOUCHER_CUTOFF_PERIOD = 1 days;
    uint256 public constant UNFREEZE_LIMIT = 5;

    // TokenReserve
    uint256 public constant LOAN_CUTOFF_PERIOD = 30 days;
    uint256 public constant SELL_AFTER_FEE = 750;
    uint256 public constant AUTOSELL_AFTER_FEE = 700;

    // DAO

    uint256 public constant VOTES_DECAY_TIME = 31 days;
    uint256 public constant VOTES_GRACE_PERIOD = 7 days;
}
