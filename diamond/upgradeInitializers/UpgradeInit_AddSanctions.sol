// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibDiamond} from "../libraries/LibDiamond.sol";

contract UpgradeInit_AddSanctions {
    function init(address aml, address expectedOwner, address expectedDao) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(ds.contractOwner == expectedOwner && ds.contracts.dao == expectedDao, "Layout error");
        ds.additionalContracts[keccak256("SANCTIONS_CONTRACT")] = aml;
    }
}
