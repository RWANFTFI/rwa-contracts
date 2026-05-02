// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibResolverLogic} from "../libraries/LibResolverLogic.sol";
import {LibVoucherLogic} from "../libraries/LibVoucherLogic.sol";
import {LibTypes} from "../libraries/LibTypes.sol";
import {Modifiers} from "../libraries/Modifiers.sol";

contract ResolverFacet is Modifiers {
    /// Activate Gift NFT
    /// @param tokenId gift tokenId
    /// @param referal referal address
    function activateGift(uint256 tokenId, address referal) external payable notBanned nonReentrant payFee {
        LibResolverLogic.activateGift(tokenId, referal);
    }

    /// Send Gift NFT to user
    /// @param to recipient
    /// @param tokenId gift tokenId
    /// @param nonce number used once
    /// @param signature signature from signer
    function giftNFT(address to, uint256 tokenId, uint256 nonce, bytes calldata signature) external payable notBanned payFee {
        LibResolverLogic.giftNFT(to, tokenId, nonce, signature);
    }

    /// Send Voucher to user
    /// @param to recipient
    /// @param tokenId voucher tokenId
    /// @param nonce number used once
    /// @param signature signature from signer
    function transferVoucher(address to, uint256 tokenId, uint256 nonce, bytes calldata signature) external payable notBanned payFee {
        LibVoucherLogic.transferVoucher(to, tokenId, nonce, signature);
    }

    function getUserTokenInfo(uint64 user) external view returns (LibTypes.UserTokenInfo memory info) {
        return LibResolverLogic.getUserTokenInfo(user);
    }

    function getUsersTokenInfo(uint64[] memory users) external view returns (LibTypes.UserTokenInfo[] memory info) {
        return LibResolverLogic.getUserTokenInfo(users);
    }

    function processRegularBought(
        uint64 user,
        uint32 level
    ) external onlySelf returns (uint256 tokenId, uint256 limit, uint256 price, uint256 autoBuys) {
        return LibResolverLogic.processRegularBought(user, level);
    }

    function processRegularUpgrade(
        uint64 user,
        uint32 level
    ) external onlySelf returns (uint256 tokenId, uint256 limit, uint256 price, uint256 autoBuys) {
        return LibResolverLogic.processRegularUpgrade(user, level);
    }

    function processGiftUpgrade(
        uint64 user,
        uint32 level
    ) external onlySelf returns (uint256 tokenId, uint256 limit, uint256 price, uint256 autoBuys) {
        return LibResolverLogic.processGiftUpgrade(user, level);
    }
}
