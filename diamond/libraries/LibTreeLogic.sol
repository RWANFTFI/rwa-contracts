// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibTreeStorage} from "../storage/LibTreeStorage.sol";
import {LibParametersStorage} from "../storage/LibParametersStorage.sol";
import {LibMarketingStorage} from "../storage/LibMarketingStorage.sol";
import {LibDiamond} from "./LibDiamond.sol";
import {LibTypes} from "./LibTypes.sol";
import {LibErrors} from "./LibErrors.sol";
import {LibEvents} from "./LibEvents.sol";

library LibTreeLogic {
    function _findPosition(LibTreeStorage.TreeStorage storage ts, uint64 sponsor) private view returns (uint64 currentParent, bool isLeft) {
        currentParent = sponsor;
        while (true) {
            if (ts.treeUsers[currentParent].left == 0) return (currentParent, true);
            else if (ts.treeUsers[currentParent].right == 0) return (currentParent, false);
            if (
                ts.subTreeUserAmount[ts.treeUsers[currentParent].left] <=
                ts.subTreeUserAmount[ts.treeUsers[currentParent].right]
            ) {
                currentParent = ts.treeUsers[currentParent].left;
            } else {
                currentParent = ts.treeUsers[currentParent].right;
            }
        }
    }

    function _placeUser(
        LibTreeStorage.TreeStorage storage ts,
        uint64 newUser,
        uint64 sponsor,
        uint64 up,
        bool isLeft
    ) private {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        ts.treeUsers[newUser] = LibTypes.Tree({up: up, left: 0, right: 0, sponsor: sponsor, active: true});
        if (isLeft) {
            ts.treeUsers[up].left = newUser;
        } else {
            ts.treeUsers[up].right = newUser;
        }
        _incrementUp(ts, newUser);
        emit LibEvents.UserPlaced(ms.identity.idToUser[newUser], ms.identity.idToUser[sponsor], ms.identity.idToUser[up], isLeft);
    }

    function _incrementUp(LibTreeStorage.TreeStorage storage ts, uint64 startUser) private {
        uint64 currentUser = ts.treeUsers[startUser].up;
        while (true) {
            if (currentUser == 0) break;
            ts.subTreeUserAmount[currentUser]++;
            currentUser = ts.treeUsers[currentUser].up;
        }
    }

    function registerUser(uint64 newUser, uint64 sponsor, bool bypassSponsorCheck) internal {
        LibTreeStorage.TreeStorage storage ts = LibTreeStorage.treeStorage();
        if (ts.treeUsers[newUser].active) revert LibErrors.UserExists();
        if (!ts.treeUsers[sponsor].active && !bypassSponsorCheck) revert LibErrors.NoReferal();
        ts.totalUsers++;
        (uint64 up, bool isleft) = _findPosition(ts, sponsor);
        _placeUser(ts, newUser, sponsor, up, isleft);
    }

    function getSponsor(uint64 user) internal view returns (uint64) {
        LibTreeStorage.TreeStorage storage ts = LibTreeStorage.treeStorage();
        return ts.treeUsers[user].sponsor;
    }

    function getUpperUsers(uint64 from, uint256 amount) internal view returns (uint64[] memory) {
        LibTreeStorage.TreeStorage storage ts = LibTreeStorage.treeStorage();
        uint64[] memory out = new uint64[](amount);
        for (uint256 i = 0; i < amount; i++) {
            if (ts.treeUsers[from].up == 0) return out;
            out[i] = (ts.treeUsers[from].up);
            from = ts.treeUsers[from].up;
        }
        return out;
    }

    function isUserExists(uint64 user) internal view returns (bool) {
        LibTreeStorage.TreeStorage storage ts = LibTreeStorage.treeStorage();
        return ts.treeUsers[user].active;
    }

    function isUserExists(address user) internal view returns (bool) {
        LibTreeStorage.TreeStorage storage ts = LibTreeStorage.treeStorage();
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        return ts.treeUsers[ms.identity.userToId[user]].active;
    }
}
