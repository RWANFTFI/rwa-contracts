// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibTypes} from "../libraries/LibTypes.sol";

library LibFarmingStorage {
    bytes32 constant FARMING_STORAGE_POSITION = keccak256("diamond.standard.farming.storage");

    struct FarmingStorage {
        mapping(uint256 => LibTypes.Mining) miners;
        mapping(uint256 => LibTypes.Farming) farmers;
        mapping(uint256 => bool) disabledTokens;
        uint256 accumulationLast;
        uint256 accumulationEnd;
    }

    function farmingStorage() internal pure returns (FarmingStorage storage ms) {
        bytes32 position = FARMING_STORAGE_POSITION;
        assembly {
            ms.slot := position
        }
    }
}
