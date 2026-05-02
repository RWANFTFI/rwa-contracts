// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibTreeLogic} from "../libraries/LibTreeLogic.sol";

contract TreeFacet {
    function getSponsor(uint64 user) external view returns (uint64) {
        return LibTreeLogic.getSponsor(user);
    }

    function getUpperUsers(uint64 from, uint256 amount) external view returns (uint64[] memory) {
        return LibTreeLogic.getUpperUsers(from, amount);
    }
}
