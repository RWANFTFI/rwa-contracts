// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibTypes} from "../libraries/LibTypes.sol";

library LibMarketingStorage {
    bytes32 constant MARKETING_STORAGE_POSITION = keccak256("diamond.standard.marketing.storage");

    struct MarketingStorage {
        LibTypes.UserId identity;
        mapping(uint64 => LibTypes.User) users;
        mapping(uint64 => LibTypes.Freeze[]) freezes;
        mapping(uint64 => uint256) lastResolvedFreezes;
        uint256 devBalance;
        uint256 tokenReserveBalance;
        uint256 priceImpactBalance;
        uint256 priceImpactStart;
        uint256 txFee;
        uint64 nextId;
        address holder;
    }

    function marketingStorage() internal pure returns (MarketingStorage storage ms) {
        bytes32 position = MARKETING_STORAGE_POSITION;
        assembly {
            ms.slot := position
        }
    }
}
