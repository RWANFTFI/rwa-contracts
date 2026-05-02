// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibMarketingLogic} from "../libraries/LibMarketingLogic.sol";
import {Modifiers} from "../libraries/Modifiers.sol";

contract MarketingFacet is Modifiers {
    /// Asign id to user
    /// @param user user address
    function createUser(address user) external onlySelf returns (uint64 userId) {
        return LibMarketingLogic.createUser(user);
    }

    /// Sell marketing structure to new user
    /// @param newOwner address of new owner
    /// @param nonce nonce
    /// @param signature signature from Backend
    function sellBusiness(address newOwner, uint256 nonce, bytes calldata signature) external payable notBanned nonReentrant payFee {
        LibMarketingLogic.sellBusiness(newOwner, nonce, signature);
    }

    /// Buy new NFT. Must provide txFee as value
    /// @param level level of NFT
    /// @param referal referal address
    /// @param vouchers vouchers for spend
    function buyNFT(uint32 level, address referal, uint256[] memory vouchers) external payable notBanned nonReentrant payFee {
        LibMarketingLogic.buyNFT(level, referal, vouchers);
    }

    /// Upgrade NFT. Must provide txFee as value
    /// @param level new lvl
    /// @param vouchers vouchers for spend
    function upgradeRegular(uint32 level, uint256[] memory vouchers) external payable notBanned payFee {
        LibMarketingLogic.upgradeRegular(level, vouchers);
    }

    /// Upgrade Gift to Regular NFT. Must provide txFee as value
    /// @param level new lvl
    /// @param vouchers vouchers for spend
    function upgradeGift(uint32 level, uint256[] memory vouchers) external payable notBanned nonReentrant payFee {
        LibMarketingLogic.upgradeGift(level, vouchers);
    }

    /// Rebuy ur level of NFT. Must provide txFee as value
    /// @param vouchers vouchers for spend
    function reBuy(uint256[] memory vouchers) external payable notBanned payFee {
        LibMarketingLogic.reBuy(vouchers);
    }

    /// Toggle autobuy status
    function toggleAutoBuy() external payable notBanned payFee {
        LibMarketingLogic.toggleAutoBuy();
    }

    function tryUnfreeze() external payable notBanned payFee {
        LibMarketingLogic.tryUnfreeze();
    }
}
