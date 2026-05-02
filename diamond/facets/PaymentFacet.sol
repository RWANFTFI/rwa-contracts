// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibMarketingLogic} from "../libraries/LibMarketingLogic.sol";
import {LibPaymentLogic} from "../libraries/LibPaymentLogic.sol";
import {LibConstants} from "../libraries/LibConstants.sol";
import {LibTypes} from "../libraries/LibTypes.sol";
import {Modifiers} from "../libraries/Modifiers.sol";

contract PaymentFacet is Modifiers {

    /// Deposit USDT to inner balance
    /// @param amount amount of USDT to deposit
    function deposit(uint256 amount) external payable notBanned payFee {
        LibPaymentLogic.deposit(amount);
    }

    /// Withdraw inner (not accumulative) balance
    /// @param amount amount to withdraw
    /// @param nonce number used once
    /// @param signature signature from signer
    function withdraw(uint256 amount, uint256 nonce, bytes calldata signature) external payable notBanned payFee {
        LibPaymentLogic.withdraw(amount, nonce, signature);
    }

    /// Transfer accumulative balance to other user
    /// @param to recipient
    /// @param amount amount of USDT
    /// @param deadline deadline of operation
    /// @param nonce number used once
    /// @param signature signature from signer
    function transferAccumulative(
        address to,
        uint256 amount,
        uint256 deadline,
        uint256 nonce,
        bytes calldata signature
    ) external payable notBanned payFee {
        LibPaymentLogic.transferAccumulative(to, amount, deadline, nonce, signature);
    }

    /// Buy voucher from inner balance
    /// @param price voucher value
    function buyVoucher(uint256 price) external payable notBanned nonReentrant payFee {
        LibPaymentLogic.buyVoucher(price);
    }

    /// Pay USDT to user with reducing his limit. Exceeds USDT will stay on sender balance
    /// @param user recipient
    /// @param amount amount of SDT
    /// @param deductFee should contract deduct fee
    /// @param description information about money source
    function reduceLimit(address user, uint256 amount, bool deductFee, string memory description) external onlyRole(LibConstants.ADMIN_ROLE) returns (uint256) {
        return LibPaymentLogic.reduceLimit(user, amount, deductFee, description);
    }

    /// Deposit USDT to Token Reserve balance
    /// @param amount amount of USDT
    function depositToTokenReserve(uint256 amount) external {
        LibPaymentLogic.depositToTokenReserve(amount);
    }

    /// Take payment for TokenReserve operations
    /// @param user payer
    /// @param amount amount of USDT 
    function takePayment(address user, uint256 amount) external onlyTokenReserve {
        LibPaymentLogic.takePayment(user, amount);
    }
}
