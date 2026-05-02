// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibMarketingStorage} from "../storage/LibMarketingStorage.sol";
import {LibTypes} from "../libraries/LibTypes.sol";
import {LibErrors} from "../libraries/LibErrors.sol";

contract Modifiers {
    modifier onlySelf() {
        require(msg.sender == address(this), "Only diamond");
        _;
    }

    modifier onlyRole(bytes32 role) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (!ds.contracts.adminContract.hasRole(role, msg.sender)) revert LibErrors.MissingRole(role);
        _;
    }

    modifier notBanned() {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        if (ms.users[ms.identity.userToId[msg.sender]].isBanned) revert LibErrors.UserBanned();
        _;
    }

    modifier onlyHolder() {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        if (msg.sender != ms.holder) revert LibErrors.AccessRestricted();
        _;
    }

    modifier onlyDAO() {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (msg.sender != ds.contracts.dao) revert LibErrors.OnlyDAO();
        _;
    }

    modifier onlyTokenReserve() {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (msg.sender != address(ds.contracts.tokenReserve)) revert LibErrors.OnlyDAO();
        _;
    }

    modifier payFee() {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        if (msg.value != ms.txFee) revert LibErrors.WrongValue();
        (bool success, ) = payable(ms.holder).call{value: msg.value}("");
        require(success, "Send failed");
        _;
    }

    modifier nonReentrant() {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (ds.reentrancyStatus == 2) revert LibErrors.Reentrancy();
        ds.reentrancyStatus = 2;
        _;
        ds.reentrancyStatus = 1;
    }
}
