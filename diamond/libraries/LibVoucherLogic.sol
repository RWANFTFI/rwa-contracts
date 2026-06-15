// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibResolverStorage} from "../storage/LibResolverStorage.sol";
import {LibParametersStorage} from "../storage/LibParametersStorage.sol";
import {LibMarketingStorage} from "../storage/LibMarketingStorage.sol";
import {LibDiamond} from "./LibDiamond.sol";
import {LibConstants} from "../libraries/LibConstants.sol";
import {LibSignatureLogic} from "../libraries/LibSignatureLogic.sol";
import {LibPaymentLogic} from "../libraries/LibPaymentLogic.sol";
import {LibMarketingLogic} from "../libraries/LibMarketingLogic.sol";
import {LibTypes} from "./LibTypes.sol";
import {LibErrors} from "./LibErrors.sol";
import {LibEvents} from "./LibEvents.sol";
import {LibUtility} from "./LibUtility.sol";

library LibVoucherLogic {
    function createVoucher(uint256 paid) internal returns (uint256) {
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        uint256 tokenId = ds.contracts.voucherContract.safeMint(msg.sender);
        rs.vouchers[tokenId] = LibTypes.Voucher(paid, block.timestamp);
        emit LibEvents.NewVoucher(msg.sender, tokenId, paid, block.timestamp);
        return tokenId;
    }

    function burnVoucher(uint256 tokenId) internal {
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        LibTypes.Voucher memory voucher = rs.vouchers[tokenId];
        if (voucher.timestamp + LibConstants.VOUCHER_DECAY_TIME >= block.timestamp) revert LibErrors.VoucherActive();
        ds.contracts.tokenReserve.deposit(voucher.value);
        ds.contracts.voucherContract.burn(tokenId);
        delete rs.vouchers[tokenId];
    }

    function reduceVoucherValue(uint256 tokenId, uint256 amount) internal {
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (ds.contracts.voucherContract.ownerOf(tokenId) != msg.sender) revert LibErrors.NotAnOwner();
        LibTypes.Voucher storage voucher = rs.vouchers[tokenId];
        if (voucher.timestamp + LibConstants.VOUCHER_DECAY_TIME < block.timestamp) revert LibErrors.VoucherExpired();

        voucher.value -= amount;
        emit LibEvents.VoucherValueReduced(tokenId, voucher.value);
    }

    function useVoucher(uint256 tokenId) internal {
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        if (ds.contracts.voucherContract.ownerOf(tokenId) != msg.sender) revert LibErrors.NotAnOwner();
        LibTypes.Voucher memory voucher = rs.vouchers[tokenId];
        if (voucher.timestamp + LibConstants.VOUCHER_DECAY_TIME < block.timestamp) revert LibErrors.VoucherExpired();
        ds.contracts.voucherContract.burn(tokenId);
        delete rs.vouchers[tokenId];
    }

    function transferVoucher(address to, uint256 tokenId, uint256 nonce, bytes calldata signature) internal {
        if (LibUtility.checkSanctioned(to)) revert LibErrors.UserSanctioned(to);
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();

        bytes32 structHash = keccak256(abi.encode(LibSignatureLogic.TRANSFER_VOUCHER_REQUEST_TYPEHASH, msg.sender, to, tokenId, nonce));
        LibSignatureLogic.verify(structHash, signature);
        if (ds.contracts.voucherContract.ownerOf(tokenId) != msg.sender) revert LibErrors.NotAnOwner();
        if (block.timestamp > rs.vouchers[tokenId].timestamp + LibConstants.VOUCHER_DECAY_TIME - LibConstants.VOUCHER_CUTOFF_PERIOD) revert LibErrors.TooLateForSending();
        ds.contracts.voucherContract.send(to, tokenId);
    }
}
