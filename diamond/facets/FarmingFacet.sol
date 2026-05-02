// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibFarmingLogic} from "../libraries/LibFarmingLogic.sol";
import {LibConstants} from "../libraries/LibConstants.sol";
import {LibTypes} from "../libraries/LibTypes.sol";
import {Modifiers} from "../libraries/Modifiers.sol";

contract FarmingFacet is Modifiers {
    /// Start mining with sender active token
    function startMining() external payable notBanned payFee{
        LibFarmingLogic.startMining();
    }

    /// Start farming with sender active token
    function startFarming() external payable notBanned payFee {
        LibFarmingLogic.startFarming();
    }

    /// Claim accumulated rewards
    function claimRewards() external payable notBanned payFee {
        LibFarmingLogic.claim();
    }
}
