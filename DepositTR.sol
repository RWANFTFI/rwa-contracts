// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.28;

import {IAdminContract} from "./interfaces/IAdminContract.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITokenReserve} from "./interfaces/ITokenReserve.sol";
import {IViewFacet} from "./diamond/interfaces/IViewFacet.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DepositTR {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SERVICE_ROLE = keccak256("SERVICE_ROLE");
    uint256 public constant MAX_INTERVAL = 10 days;
    uint256 public constant MIN_INTERVAL = 1 days;
    uint256 public constant MAX_PERCENT = 1000;
    uint256 public constant MIN_PERCENT = 100;

    uint256 public interval = 1 days;
    uint256 public lastDeposit;
    IERC20 public payment;
    IViewFacet public viewFacet;

    error OutOfRange();
    error ZeroDeposit();
    error EarlyToDeposit();

    event DepositIn(uint256 amount);
    event DepositOut(uint256 amount);

    modifier onlyRole(bytes32 role) {
        if (!viewFacet.getContracts().adminContract.hasRole(role, msg.sender)) revert IAdminContract.MissingRole(role);
        _;
    }

    constructor( address diamondAddress, address paymentAddress) {
        payment = IERC20(paymentAddress);
        viewFacet = IViewFacet(diamondAddress);
    }

    function deposit(uint256 percent) external onlyRole(SERVICE_ROLE) {
        if (percent < MIN_PERCENT || percent > MAX_PERCENT) revert OutOfRange();
        if (block.timestamp < lastDeposit + interval) revert EarlyToDeposit();
        lastDeposit = block.timestamp;
        uint256 toDeposit = payment.balanceOf(address(this)) * percent / MAX_PERCENT;
        ITokenReserve tokenReserve = viewFacet.getContracts().tokenReserve;
        payment.approve(address(tokenReserve), toDeposit);
        tokenReserve.deposit(toDeposit);
        emit DepositOut(toDeposit);
    }

    function depositUSDT(uint256 amount) external {
        if (amount == 0) revert ZeroDeposit();
        payment.safeTransferFrom(msg.sender, address(this), amount);
        emit DepositIn(amount);
    }

    function setInterval(uint256 newInterval) external onlyRole(ADMIN_ROLE) {
        if (newInterval < MIN_INTERVAL || newInterval > MAX_INTERVAL) revert OutOfRange();
        interval = newInterval;
    }
}
