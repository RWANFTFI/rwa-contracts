// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibTreeLogic} from "../libraries/LibTreeLogic.sol";
import {LibParametersLogic} from "../libraries/LibParametersLogic.sol";
import {LibMarketingStorage} from "../storage/LibMarketingStorage.sol";
import {LibResolverStorage} from "../storage/LibResolverStorage.sol";
import {LibFarmingStorage} from "../storage/LibFarmingStorage.sol";
import {LibTreeStorage} from "../storage/LibTreeStorage.sol";
import {LibParametersStorage} from "../storage/LibParametersStorage.sol";
import {LibTypes} from "../libraries/LibTypes.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibConstants} from "../libraries/LibConstants.sol";

contract ViewFacet {
    function getUser(address user) external view returns (LibTypes.User memory) {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        return ms.users[ms.identity.userToId[user]];
    }

    function getFreeze(address user, uint256 index) external view returns (LibTypes.Freeze memory) {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        return ms.freezes[ms.identity.userToId[user]][index];
    }

    function getLastResolverFreeze(address user) external view returns (uint256) {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        return ms.lastResolvedFreezes[ms.identity.userToId[user]];
    }

    function getTxFee() external view returns (uint256) {
        return LibMarketingStorage.marketingStorage().txFee;
    }

    function getTxFeeRanges() external view returns (uint256 min, uint256 max) {
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        return (ps.txFeeMin, ps.txFeeMax);
    }

    function getDevBalance() external view returns (uint256) {
        return LibMarketingStorage.marketingStorage().devBalance;
    }

    function getTokenReserveBalance() external view returns (uint256) {
        return LibMarketingStorage.marketingStorage().tokenReserveBalance;
    }

    function getHolderAddress() external view returns (address) {
        return LibMarketingStorage.marketingStorage().holder;
    }

    function getTreeUser(address user) external view returns (LibTypes.Tree memory) {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        return LibTreeStorage.treeStorage().treeUsers[ms.identity.userToId[user]];
    }

    function getRegisteredToken(uint256 tokenId) external view returns (LibTypes.RegisteredNFT memory) {
        return LibResolverStorage.resolverStorage().registeredTokens[tokenId];
    }

    function getRegularMintedAmountByLevel(uint32 level) external view returns (uint256) {
        return LibResolverStorage.resolverStorage().minted[level];
    }

    function getGiftMintedAmountByLevel(uint32 level) external view returns (uint256) {
        return LibResolverStorage.resolverStorage().giftsMinted[level];
    }

    function getVoucher(uint256 tokenId) external view returns (LibTypes.Voucher memory) {
        return LibResolverStorage.resolverStorage().vouchers[tokenId];
    }

    function getMiningStatusByTokenId(uint256 tokenId) external view returns(LibTypes.Mining memory) {
        return LibFarmingStorage.farmingStorage().miners[tokenId];
    }

    function getFarmingStatusByTokenId(uint256 tokenId) external view returns(LibTypes.Farming memory) {
        return LibFarmingStorage.farmingStorage().farmers[tokenId];
    }

    function getSponsor(address user) external view returns(address) {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibTreeStorage.TreeStorage storage fs = LibTreeStorage.treeStorage();
        return ms.identity.idToUser[fs.treeUsers[ms.identity.userToId[user]].sponsor];
    }

    function getUserAddressById(uint64 id) external view returns(address) {
        return LibMarketingStorage.marketingStorage().identity.idToUser[id];
    }

    function getUserIdByAddress(address user) external view returns(uint64) {
        return LibMarketingStorage.marketingStorage().identity.userToId[user];
    }

    function getContracts() external view returns(LibTypes.Contracts memory) {
        return LibDiamond.diamondStorage().contracts;
    }

    function getActiveToken(address user) external view returns(uint256) {
        uint64 userId = LibMarketingStorage.marketingStorage().identity.userToId[user];
        return LibResolverStorage.resolverStorage().owners[userId];
    }

    function getPriceImpactBalance() external view returns(uint256) {
        return LibMarketingStorage.marketingStorage().priceImpactBalance;
    }

    function getPriceImpactStartTimestamp() external view returns(uint256) {
        return LibMarketingStorage.marketingStorage().priceImpactStart;
    }

    function getTokenDisabledStatus(uint256 tokenId) external view returns(bool) {
        return LibFarmingStorage.farmingStorage().disabledTokens[tokenId];
    }

    function getSignatureVerifyStatus() external view returns(bool) {
        return LibDiamond.diamondStorage().signatureVerify;
    }

    function getDaoAddress() external view returns(address) {
        return LibDiamond.diamondStorage().contracts.dao;
    }

    function getLastAccumulationEventTimestamp() external view returns(uint256) {
        return LibFarmingStorage.farmingStorage().accumulationLast;
    }

    function getAccumulationEventEndTimestamp() external view returns(uint256) {
        return LibFarmingStorage.farmingStorage().accumulationEnd;
    }

    function getConstants() external pure returns(LibTypes.Constants memory) {
        return LibParametersLogic.getConstants();
    }

    function getAdditionalContract(string calldata name) external view returns(address) {
        return LibDiamond.diamondStorage().additionalContracts[keccak256(abi.encodePacked(name))];
    }
}
