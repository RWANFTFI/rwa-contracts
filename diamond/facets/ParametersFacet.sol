// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibParametersLogic} from "../libraries/LibParametersLogic.sol";
import {LibParametersStorage} from "../storage/LibParametersStorage.sol";
import {LibTypes} from "../libraries/LibTypes.sol";
import {Modifiers} from "../libraries/Modifiers.sol";
import {LibConstants} from "../libraries/LibConstants.sol";

contract ParametersFacet is Modifiers {
    /// Create new type of Gift NFT
    /// @param gift gift parameters (provided level unused)
    /// @param ranges gift parameters ranges
    function addGiftNFT(
        LibTypes.GiftNFT memory gift,
        LibTypes.RangesGift memory ranges
    ) external onlyRole(LibConstants.ADMIN_ROLE) {
        LibParametersLogic.addGiftNFT(gift, ranges);
    }

    /// Apply new parameters to Gift NFT
    /// @param level level(type) of gift NFT
    /// @param updates array of parameter updates
    function changeGiftNFT(
        uint32 level,
        LibTypes.GiftUpdate[] calldata updates
    ) external onlyRole(LibConstants.ADMIN_ROLE) {
        LibParametersLogic.changeGiftNFT(level, updates);
    }

    /// Update project parameters via DAO
    /// @param updates array of updates
    function applyParameterUpdates(LibTypes.ParameterUpdate[] calldata updates) external onlyDAO {
        LibParametersLogic.applyParameterUpdates(updates);
    }

    /// Apply new parameters to Regular NFT via DAO
    /// @param level level of Regular NFT
    /// @param updates array of updates
    function changeNFT(uint256 level, LibTypes.NFTUpdate[] calldata updates) external onlyDAO {
        LibParametersLogic.changeNFT(level, updates);
    }

    /// Enable or Disable Regular NFT via DAO
    /// @param level level of Regular NFT
    /// @param isDisabled new status
    function setDisabledStatus(uint32 level, bool isDisabled) external onlyDAO {
        LibParametersLogic.setDisabledStatus(level, isDisabled);
    }

    /// Apply new mining periods via DAO
    /// @param level level of Regular NFT
    /// @param periods new periods
    function setFarmingPeriods(uint32 level, uint32[] memory periods) external onlyDAO {
        LibParametersLogic.setFarmingPeriods(level, periods);
    }

    /// Change allowed range for txFee
    /// @param min minimum
    /// @param max maximum
    function setTxFeeRanges(uint256 min, uint256 max) external onlyDAO() {
        LibParametersLogic.setTxFeeRanges(min, max);
    }

    // -------- Getters --------
    function getRegular(uint32 level) external view returns (LibTypes.NFT memory) {
        return LibParametersStorage.parametersStorage().regularTypes[level];
    }

    function getRegularPrice(uint32 level) external view returns (uint256) {
        return LibParametersStorage.parametersStorage().regularTypes[level].price;
    }

    function getGift(uint32 level) external view returns (LibTypes.GiftNFT memory) {
        return LibParametersStorage.parametersStorage().giftTypes[level];
    }

    function matchingThresholds() public view returns (uint80[3] memory) {
        return LibParametersStorage.parametersStorage().parameters.matchingThresholds;
    }

    function accumulativeClaimDistribute() public view returns (uint16[3] memory) {
        return LibParametersStorage.parametersStorage().parameters.accumulativeClaimDistribute;
    }

    function accumulativeClaimDistributeGift() public view returns (uint16[3] memory) {
        return LibParametersStorage.parametersStorage().parameters.accumulativeClaimDistributeGift;
    }

    function distribution() public view returns (uint8[22] memory) {
        return LibParametersStorage.parametersStorage().parameters.distribution;
    }

    function autoSellPeriods() public view returns (uint24[4] memory) {
        return LibParametersStorage.parametersStorage().parameters.autoSellPeriods;
    }

    function getParameters() external view returns (LibTypes.Parameters memory) {
        return LibParametersStorage.parametersStorage().parameters;
    }

    function getFee() external view returns (uint256) {
        return LibParametersStorage.parametersStorage().parameters.fee;
    }

    function getLoanFee() external view returns (uint256) {
        return LibParametersStorage.parametersStorage().parameters.loanFee;
    }
}
