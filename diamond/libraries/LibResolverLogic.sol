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
import {ITokenReserve} from "../../interfaces/ITokenReserve.sol";
import {LibUtility} from "./LibUtility.sol";

library LibResolverLogic {
    function _giftUpgrade(uint64 ownerId, uint256 tokenId, uint32 level) private returns (uint256) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();

        address owner = ms.identity.idToUser[ownerId];
        uint256 regularId = ds.contracts.regularContract.safeMint(owner);
        ds.contracts.giftContract.burn(owner, tokenId);
        rs.registeredTokens[regularId] = LibTypes.RegisteredNFT({
            owner: ownerId,
            level: level,
            typeNFT: LibTypes.TypeNFT.REGULAR,
            isActive: true
        });
        rs.owners[ownerId] = regularId;
        ms.users[ownerId].tokenId = regularId;
        delete rs.registeredTokens[tokenId];
        return regularId;
    }

    function processGiftUpgrade(
        uint64 user,
        uint32 level
    ) internal returns (uint256 tokenId, uint256 limit, uint256 price, uint256 autoBuys) {
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();

        tokenId = rs.owners[user];
        if (tokenId == 0) revert LibErrors.UserNotActive();

        LibTypes.NFT memory token = ps.regularTypes[level];
        if (token.isDisabled || token.unlocksAfter > block.timestamp) revert LibErrors.RestrictedLevel();
        if (rs.minted[level] >= token.supply) revert LibErrors.OutOfStock();

        LibTypes.RegisteredNFT memory nft = rs.registeredTokens[tokenId];
        if (nft.typeNFT != LibTypes.TypeNFT.GIFT) revert LibErrors.WrongType();

        LibTypes.GiftNFT memory gift = ps.giftTypes[nft.level];
        if (level < gift.allowedUpgradeLevel) revert LibErrors.LowLevel();
        tokenId = _giftUpgrade(user, tokenId, level);
        rs.minted[level]++;
        limit = token.limit;
        price = token.price;
        autoBuys = token.autoBuys;
    }

    function processRegularBought(
        uint64 user,
        uint32 level
    ) internal returns (uint256 tokenId, uint256 limit, uint256 price, uint256 autoBuys) {
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        LibTypes.NFT memory token = ps.regularTypes[level];
        if (token.isDisabled || token.unlocksAfter > block.timestamp) revert LibErrors.RestrictedLevel();
        if (rs.minted[level] >= token.supply) revert LibErrors.OutOfStock();

        if (rs.owners[user] != 0) revert LibErrors.UserActive();
        tokenId = ds.contracts.regularContract.safeMint(ms.identity.idToUser[user]);
        rs.registeredTokens[tokenId] = LibTypes.RegisteredNFT({
            owner: user,
            level: level,
            typeNFT: LibTypes.TypeNFT.REGULAR,
            isActive: true
        });
        ms.users[user].tokenId = tokenId;
        rs.owners[user] = tokenId;
        rs.minted[level]++;
        limit = token.limit;
        price = token.price;
        autoBuys = token.autoBuys;
    }

    function processRegularUpgrade(
        uint64 user,
        uint32 level
    ) internal returns (uint256 tokenId, uint256 limit, uint256 price, uint256 autoBuys) {
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();

        if (rs.owners[user] == 0) revert LibErrors.UserNotActive();

        LibTypes.NFT memory token = ps.regularTypes[level];
        if (token.isDisabled || token.unlocksAfter > block.timestamp) revert LibErrors.RestrictedLevel();

        tokenId = rs.owners[user];
        LibTypes.RegisteredNFT storage nft = rs.registeredTokens[tokenId];
        if (nft.typeNFT != LibTypes.TypeNFT.REGULAR) revert LibErrors.WrongType();
        uint32 currentLevel = nft.level;
        if (level <= currentLevel) revert LibErrors.LowLevel();
        if (rs.minted[level] >= token.supply) revert LibErrors.OutOfStock();
        nft.level = level;
        rs.minted[level]++;
        limit = token.limit;
        price = token.price;
        autoBuys = token.autoBuys;
    }

    function _mintGift(
        LibResolverStorage.ResolverStorage storage rs,
        LibMarketingStorage.MarketingStorage storage ms,
        LibDiamond.DiamondStorage storage ds,
        address to,
        uint32 level
    ) private returns (uint256) {
        uint256 tokenId = ds.contracts.giftContract.getNextTokenId();
        emit LibEvents.GiftGranted(to, tokenId, level);
        ds.contracts.giftContract.safeMint(to);
        rs.registeredTokens[tokenId] = LibTypes.RegisteredNFT({
            owner: ms.identity.userToId[to],
            level: level,
            typeNFT: LibTypes.TypeNFT.GIFT,
            isActive: false
        });
        rs.giftsMinted[level]++;
        return tokenId;
    }

    function mintGiftNFT(LibTypes.GiftToMint[] calldata toMint) internal {
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        for (uint256 lIndex; lIndex < toMint.length; lIndex++) {
            LibTypes.GiftNFT memory gift = ps.giftTypes[toMint[lIndex].level];
            for (uint256 rIndex; rIndex < toMint[lIndex].recipients.length; rIndex++) {
                if (rs.giftsMinted[toMint[lIndex].level] + toMint[lIndex].recipients[rIndex].amount > gift.supply) revert LibErrors.OutOfStock();
                for (uint256 i; i < toMint[lIndex].recipients[rIndex].amount; i++) {
                    _mintGift(rs, ms, ds, toMint[lIndex].recipients[rIndex].recipient, toMint[lIndex].level);
                }
            }
        }
    }

    function giftNFT(address to, uint256 tokenId, uint256 nonce, bytes calldata signature) internal {
        if (LibUtility.checkSanctioned(to)) revert LibErrors.UserSanctioned(to);
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();

        bytes32 structHash = keccak256(
            abi.encode(LibSignatureLogic.GIFT_REQUEST_TYPEHASH, msg.sender, to, tokenId, nonce)
        );
        LibSignatureLogic.verify(structHash, signature);
        if (ds.contracts.giftContract.ownerOf(tokenId) != msg.sender) revert LibErrors.NotAnOwner();
        if (rs.registeredTokens[tokenId].isActive) revert LibErrors.GiftActive();
        if (ds.contracts.giftContract.balanceOf(to) >= ps.parameters.giftHoldLimit) revert LibErrors.TooManyGifts();
        LibPaymentLogic.paymentForGiftTransfer(msg.sender);
        ds.contracts.giftContract.sendGift(to, tokenId);
    }

    function _getUserTokenInfo(
        LibResolverStorage.ResolverStorage storage rs,
        LibParametersStorage.ParametersStorage storage ps,
        uint64 user
    ) private view returns (LibTypes.UserTokenInfo memory info) {
        uint32 level = rs.registeredTokens[rs.owners[user]].level;
        if (rs.registeredTokens[rs.owners[user]].typeNFT == LibTypes.TypeNFT.REGULAR) {
            LibTypes.NFT memory token = ps.regularTypes[level];
            info.tokenId = rs.owners[user];
            info.accumulativePercent = ps.parameters.accumulativePercent;
            info.price = token.price;
            info.limit = token.limit;
            info.autoBuys = token.autoBuys;
            info.allowedDeep = token.earnLevels;
            info.level = level;
            info.typeNft = LibTypes.TypeNFT.REGULAR;
            info.isDisabled = token.isDisabled;
            info.farmingTime = token.farmingTime;
            info.miningTime = token.miningTime;
            info.periods = token.periods;
        } else {
            LibTypes.GiftNFT memory gift = ps.giftTypes[level];
            info.tokenId = rs.owners[user];
            info.accumulativePercent = gift.accumulativePercent;
            info.price = gift.price;
            info.limit = gift.limit;
            info.autoBuys = 0;
            info.allowedDeep = gift.earnLevels;
            info.level = level;
            info.typeNft = LibTypes.TypeNFT.GIFT;
            info.isDisabled = false;
        }
    }

    function getUserTokenInfo(uint64 user) internal view returns (LibTypes.UserTokenInfo memory info) {
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        return _getUserTokenInfo(rs, ps, user);
    }

    function getUserTokenInfo(address user) internal view returns (LibTypes.UserTokenInfo memory info) {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        return getUserTokenInfo(ms.identity.userToId[user]);
    }

    function getUserTokenInfo(uint64[] memory users) internal view returns (LibTypes.UserTokenInfo[] memory) {
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();

        LibTypes.UserTokenInfo[] memory info = new LibTypes.UserTokenInfo[](users.length);
        for (uint256 i; i < users.length; i++) {
            info[i] = _getUserTokenInfo(rs, ps, users[i]);
        }
        return info;
    }

    function mintAmb(address user) internal {
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        if (rs.registeredTokens[rs.owners[ms.identity.userToId[user]]].typeNFT != LibTypes.TypeNFT.REGULAR)
            revert LibErrors.WrongType();
        uint256 tokenId = ds.contracts.ambContract.safeMint(user);
        emit LibEvents.AmbassadorGranted(user, tokenId);
    }

    function transferAmb(address to, uint256 tokenId) internal {
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        if (
            !ds.contracts.adminContract.hasRole(LibConstants.ADMIN_ROLE, to) &&
            rs.registeredTokens[rs.owners[ms.identity.userToId[to]]].typeNFT != LibTypes.TypeNFT.REGULAR
        ) revert LibErrors.WrongType();
        address owner = ds.contracts.ambContract.ownerOf(tokenId);
        ds.contracts.ambContract.send(to, tokenId);
        emit LibEvents.AmbassadorRevoked(owner, tokenId);
        emit LibEvents.AmbassadorGranted(to, tokenId);
    }

    function activateGift(uint256 tokenId, address referal) internal {
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        if (rs.registeredTokens[tokenId].isActive) revert LibErrors.GiftActive();
        if (rs.registeredTokens[tokenId].typeNFT != LibTypes.TypeNFT.GIFT) revert LibErrors.WrongType();
        if (ds.contracts.giftContract.ownerOf(tokenId) != msg.sender) revert LibErrors.NotAnOwner();

        LibTypes.GiftNFT memory gift = ps.giftTypes[rs.registeredTokens[tokenId].level];
        uint64 referalId = ms.identity.userToId[referal];
        if (referalId == 0) revert LibErrors.NoReferal();
        uint64 senderId = LibMarketingLogic.register(ms, msg.sender, referalId, false);
        ms.users[senderId].limit = gift.limit;
        ms.users[senderId].tokenId = tokenId;
        rs.owners[senderId] = tokenId;
        rs.registeredTokens[tokenId].isActive = true;
        rs.registeredTokens[tokenId].owner = senderId;
        emit LibEvents.GiftActivated(msg.sender, tokenId);
    }

    function changeUserAddress(address newOwner, address oldOwner) internal {
        if (LibUtility.checkSanctioned(newOwner)) revert LibErrors.UserSanctioned(newOwner);
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        if (ms.identity.userToId[newOwner] != 0) revert LibErrors.UserExists();
        uint64 oldId = ms.identity.userToId[oldOwner];
        ms.identity.userToId[newOwner] = oldId;
        ms.identity.userToId[oldOwner] = 0;
        ms.identity.idToUser[oldId] = newOwner;
        ITokenReserve(ds.contracts.tokenReserve).changeWallet(oldOwner, newOwner);

        uint256 tokenId = rs.owners[oldId];
        if (rs.registeredTokens[tokenId].typeNFT == LibTypes.TypeNFT.REGULAR) {
            ds.contracts.regularContract.send(newOwner, tokenId);
        } else {
            if (ds.contracts.giftContract.balanceOf(newOwner) >= ps.parameters.giftHoldLimit) revert LibErrors.TooManyGifts();
            ds.contracts.giftContract.sendGift(newOwner, tokenId);
        }
    }
}
