// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibDiamond} from "./LibDiamond.sol";
import {LibConstants} from "../libraries/LibConstants.sol";
import {ISanctionsList} from "../../interfaces/ISanctionsList.sol";

library LibUtility {
    function checkSanctioned(address user) internal view returns(bool) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ISanctionsList(ds.additionalContracts[LibConstants.SANCTIONS_CONTRACT]).isSanctioned(user);
    }
}
