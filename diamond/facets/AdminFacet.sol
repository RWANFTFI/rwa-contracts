// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Modifiers} from "../libraries/Modifiers.sol";
import {LibMarketingLogic} from "../libraries/LibMarketingLogic.sol";
import {LibVoucherLogic} from "../libraries/LibVoucherLogic.sol";
import {LibPaymentLogic} from "../libraries/LibPaymentLogic.sol";
import {LibTypes} from "../libraries/LibTypes.sol";
import {LibEvents} from "../libraries/LibEvents.sol";
import {LibConstants} from "../libraries/LibConstants.sol";
import {LibResolverLogic} from "../libraries/LibResolverLogic.sol";
import {LibFarmingLogic} from "../libraries/LibFarmingLogic.sol";
import {LibSignatureLogic} from "../libraries/LibSignatureLogic.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract AdminFacet is Modifiers {

    /// Sets new contract for DAO
    /// @param newDAO new dao contract address
    function setDAO(address newDAO) external onlyDAO {
        LibDiamond.diamondStorage().contracts.dao = newDAO;
        emit LibEvents.NewDAO(newDAO);
    }

    /// Sets user ban status
    /// @param user user address
    /// @param status ban status
    function setBanStatus(address user, bool status) external onlyDAO {
        LibMarketingLogic.setBanStatus(user, status);
    }

    /// Disable or enable mining for specific tokenId
    /// @param tokenId tokenId
    /// @param status new status
    function suspendToken(uint256 tokenId, bool status) external onlyDAO {
        LibFarmingLogic.suspendToken(tokenId, status);
    }

    /// Change user address linked to his ID
    /// @param newOwner new address
    /// @param oldOwner old address
    function changeWallet(address newOwner, address oldOwner) external onlyDAO nonReentrant {
        LibMarketingLogic.changeWallet(newOwner, oldOwner);
    }

    /// Set start time for Price impact event (all earnings going to increase DA price)
    /// @param timestamp start timestamp
    function startPriceImpactEvent(uint256 timestamp) external onlyDAO {
        LibMarketingLogic.startPriceImpactEvent(timestamp);
    }

    /// Claim dev percent or funds for Token Reserve
    /// @param amount USDT amount to claim
    /// @param isTokenReserve true if claims for TR
    function claim(uint256 amount, bool isTokenReserve) external onlyHolder {
        LibPaymentLogic.claim(amount, isTokenReserve);
    }

    /// Transfer Holder rights
    /// @param newHolder new holder address
    function changeHolder(address newHolder) external onlyHolder {
        LibPaymentLogic.changeHolder(newHolder);
    }

    /// Claim expired freezes
    /// @param usrs array of users with expired freezes
    function claimFreezes(address[] calldata usrs, uint256[] calldata amounts) external onlyRole(LibConstants.SERVICE_ROLE) {
        LibMarketingLogic.claimFreezes(usrs, amounts);
    }

    /// Crosschain deposit for users
    /// @param user user address
    /// @param amount USDT amount
    /// @param source source of deposit
    function depositToUser(address user, uint256 amount, string memory source) external onlyRole(LibConstants.SERVICE_ROLE) {
        LibPaymentLogic.depositToUser(user, amount, source);
    }

    /// Burn expired voucher
    /// @param tokenId Id to burn
    function burnVoucher(uint256 tokenId) external onlyRole(LibConstants.SERVICE_ROLE) {
        LibVoucherLogic.burnVoucher(tokenId);
    }

    /// Withdraw expired accumulative from user
    /// @param user user address
    function withdrawAccumulative(address user) external onlyRole(LibConstants.SERVICE_ROLE) {
        LibPaymentLogic.withdrawAccumulative(user);
    }

    /// Send earned to DA
    function proceedPriceImpactEarnings() external onlyRole(LibConstants.SERVICE_ROLE) {
        LibMarketingLogic.proceedPriceImpactEarnings();
    }

    /// Starts accumulation event.
    /// @notice blocks new minings for 30 days. Can be executed with 180 days interval
    function startAccumulationEvent() external onlyRole(LibConstants.SERVICE_ROLE) {
        LibFarmingLogic.startAccumulationEvent();
    }

    /// Interrupt accumulation event early
    function interruptAccumulationEvent() external onlyDAO {
        LibFarmingLogic.interruptAccumulationEvent();
    }
    
    /// Mint Gift NFT to users
    /// @param toMint levels, recipients and amounts to mint
    function mintGiftNFT(LibTypes.GiftToMint[] calldata toMint) external onlyRole(LibConstants.MINTER_ROLE) nonReentrant {
        LibResolverLogic.mintGiftNFT(toMint);
    }

    /// Set txFee for buy methods. Limited by params
    /// @param fee new fee value
    function setTxFee(uint256 fee) external onlyRole(LibConstants.ADMIN_ROLE) {
        LibPaymentLogic.setTxFee(fee);
    }

    /// Mint Ambassador NFT to user
    /// @param user user address
    function mintAmb(address user) external onlyRole(LibConstants.MINTER_ROLE) {
        LibResolverLogic.mintAmb(user);
    }

    /// Transfer Ambassador NFT from one user to other
    /// @param recipient new owner
    /// @param tokenId tokenId
    function transferAmb(address recipient, uint256 tokenId) external onlyRole(LibConstants.ADMIN_ROLE) {
        LibResolverLogic.transferAmb(recipient, tokenId);
    }

    /// Enable or disable 2FA
    /// @param status new status
    function signatureVerifyStatus(bool status) external onlyRole(LibConstants.SECURED_ROLE) {
        LibSignatureLogic.signatureVerifyStatus(status);
    }
}
