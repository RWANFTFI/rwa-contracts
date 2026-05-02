// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibTypes} from "../libraries/LibTypes.sol";

library LibResolverStorage {
    bytes32 constant RESOLVER_STORAGE_POSITION = keccak256("diamond.standard.resolver.storage");

    struct ResolverStorage {
        mapping(uint256 => LibTypes.RegisteredNFT) registeredTokens;
        mapping(uint64 => uint256) owners; // active tokenId by owner
        mapping(uint32 => uint256) minted;
        mapping(uint32 => uint256) giftsMinted;
        mapping(uint256 => LibTypes.Voucher) vouchers;
    }

    function resolverStorage() internal pure returns (ResolverStorage storage rs) {
        bytes32 position = RESOLVER_STORAGE_POSITION;
        // assigns struct storage slot to the storage position
        assembly {
            rs.slot := position
        }
    }
}
