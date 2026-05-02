// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibTypes} from "../libraries/LibTypes.sol";

library LibTreeStorage {
    bytes32 constant TREE_STORAGE_POSITION = keccak256("diamond.standard.tree.storage");

    struct TreeStorage {
        mapping(uint64 => LibTypes.Tree) treeUsers;
        mapping(uint64 => uint256) subTreeUserAmount;
        uint256 totalUsers;
        uint256 maxDepth;
    }

    function treeStorage() internal pure returns (TreeStorage storage ts) {
        bytes32 position = TREE_STORAGE_POSITION;
        assembly {
            ts.slot := position
        }
    }
}
