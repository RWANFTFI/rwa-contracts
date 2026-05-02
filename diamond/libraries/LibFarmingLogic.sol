// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibResolverStorage} from "../storage/LibResolverStorage.sol";
import {LibParametersStorage} from "../storage/LibParametersStorage.sol";
import {LibMarketingStorage} from "../storage/LibMarketingStorage.sol";
import {LibFarmingStorage} from "../storage/LibFarmingStorage.sol";
import {LibDiamond} from "./LibDiamond.sol";
import {LibConstants} from "../libraries/LibConstants.sol";
import {LibPaymentLogic} from "../libraries/LibPaymentLogic.sol";
import {LibMarketingLogic} from "../libraries/LibMarketingLogic.sol";
import {LibTypes} from "./LibTypes.sol";
import {LibErrors} from "./LibErrors.sol";
import {LibEvents} from "./LibEvents.sol";
import {LibResolverLogic} from "./LibResolverLogic.sol";

library LibFarmingLogic {

    function _getTokenInfo() private view returns(LibTypes.UserTokenInfo memory tokenInfo) {
        tokenInfo = LibResolverLogic.getUserTokenInfo(msg.sender);
        if (tokenInfo.tokenId == 0) revert LibErrors.UserNotExists();
        if (tokenInfo.typeNft != LibTypes.TypeNFT.REGULAR || tokenInfo.miningTime == 0) revert LibErrors.AccessRestricted();
    }

    function init(uint256 miningDelay) internal {
        LibFarmingStorage.FarmingStorage storage fs = LibFarmingStorage.farmingStorage();
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + miningDelay;
        fs.accumulationLast = endTime; // 180 days should be counted from this time
        fs.accumulationEnd = endTime;
        emit LibEvents.AccumulationEventStart(startTime, endTime);
    }

    /// Start mining with sender active token
    function startMining() internal {
        LibFarmingStorage.FarmingStorage storage fs = LibFarmingStorage.farmingStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        
        if (block.timestamp < fs.accumulationEnd) revert LibErrors.AccumulationPeriodIsActive();
        if (ms.users[ms.identity.userToId[msg.sender]].limit == 0) revert LibErrors.EmptyLimit();

        LibTypes.UserTokenInfo memory tokenInfo = _getTokenInfo();

        uint256 tokenId = tokenInfo.tokenId;
        if (fs.disabledTokens[tokenId]) revert LibErrors.TokenSuspended();

        LibTypes.Mining storage miner = fs.miners[tokenId];
        LibTypes.Farming storage farmer = fs.farmers[tokenId];

        if (miner.isActive) {
            if (block.timestamp < miner.endTime) revert LibErrors.MiningInProcess();
            if (block.timestamp < miner.endTime + ps.parameters.decayTimeNFTM) revert LibErrors.EarlyToStart();
            else miner.period = 0;
        }
        if (farmer.isActive) revert LibErrors.FarmingInProcess();

        if (miner.period >= tokenInfo.periods.length) miner.period = 0;

        uint256 endTime = block.timestamp + tokenInfo.miningTime;
        miner.endTime = endTime;
        miner.tokenId = tokenId;
        miner.reward = tokenInfo.price * tokenInfo.periods[miner.period] / LibConstants.DENOMINATOR;
        miner.isActive = true;
        emit LibEvents.MiningStarted(msg.sender, tokenId, endTime, miner.reward, miner.period);
    }

    /// Start farming with sender active token
    function startFarming() internal {
        LibTypes.UserTokenInfo memory tokenInfo = _getTokenInfo();

        LibFarmingStorage.FarmingStorage storage fs = LibFarmingStorage.farmingStorage();
        LibParametersStorage.ParametersStorage storage ps = LibParametersStorage.parametersStorage();
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();

        if (ms.users[ms.identity.userToId[msg.sender]].limit == 0) revert LibErrors.EmptyLimit();
        uint256 tokenId = tokenInfo.tokenId;
        if (fs.disabledTokens[tokenId]) revert LibErrors.TokenSuspended();

        LibTypes.Mining storage miner = fs.miners[tokenId];
        LibTypes.Farming storage farmer = fs.farmers[tokenId];

        if (block.timestamp < miner.endTime) revert LibErrors.MiningInProcess();
        if (farmer.isActive) revert LibErrors.FarmingInProcess();
        if (!miner.isActive) revert LibErrors.MiningIsMissing();
        if (block.timestamp > miner.endTime + ps.parameters.decayTimeNFTM) revert LibErrors.LateToStart();

        uint256 endTime = block.timestamp + tokenInfo.farmingTime;
        miner.isActive = false;
        farmer.endTime = endTime;
        farmer.isActive = true;

        emit LibEvents.FarmingStarted(msg.sender, tokenId, endTime, miner.reward, miner.period);
    }

    /// Claim accumulated rewards
    function claim() internal {
        LibTypes.UserTokenInfo memory tokenInfo = _getTokenInfo();

        LibFarmingStorage.FarmingStorage storage fs = LibFarmingStorage.farmingStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();

        if (ms.users[ms.identity.userToId[msg.sender]].limit == 0) revert LibErrors.EmptyLimit();

        uint256 tokenId = tokenInfo.tokenId;
        if (fs.disabledTokens[tokenId]) revert LibErrors.TokenSuspended();

        LibTypes.Mining storage miner = fs.miners[tokenId];
        LibTypes.Farming storage farmer = fs.farmers[tokenId];
        if (!farmer.isActive) revert LibErrors.NothingToClaim();
        if (block.timestamp < farmer.endTime) revert LibErrors.FarmingInProcess();

        farmer.isActive = false;
        miner.period++;

        uint256 price = ds.contracts.tokenReserve.getPrice();
        uint256 toPay = miner.reward * 1e18 / price;
        miner.reward = 0;
        miner.endTime = 0;
        miner.isActive = false;
        ds.contracts.tokenReserve.claimReserveTo(msg.sender, toPay);
        emit LibEvents.Claimed(msg.sender, tokenId, toPay, price);
    }

    /// Terminate user mining/farming (ex after nft purchase by user)
    /// @param user miner/farmer address
    function terminate(address user) internal {
        LibFarmingStorage.FarmingStorage storage fs = LibFarmingStorage.farmingStorage();
        LibTypes.UserTokenInfo memory tokenInfo = LibResolverLogic.getUserTokenInfo(user);
        if (fs.miners[tokenInfo.tokenId].isActive || fs.farmers[tokenInfo.tokenId].isActive)
            emit LibEvents.Terminated(user, tokenInfo.tokenId, block.timestamp);
        delete fs.miners[tokenInfo.tokenId];
        delete fs.farmers[tokenInfo.tokenId];
    }

    function suspendToken(uint256 tokenId, bool status) internal {
        LibFarmingStorage.FarmingStorage storage fs = LibFarmingStorage.farmingStorage();
        fs.disabledTokens[tokenId] = status;
        emit LibEvents.TokenSuspensionStatusChanged(tokenId, status);
    }

    function startAccumulationEvent() internal {
        LibFarmingStorage.FarmingStorage storage fs = LibFarmingStorage.farmingStorage();
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 30 days;
        if (startTime < fs.accumulationLast + 180 days) revert LibErrors.TooEarly();
        fs.accumulationLast = startTime;
        fs.accumulationEnd = endTime;
        emit LibEvents.AccumulationEventStart(startTime, endTime);
    }

    function interruptAccumulationEvent() internal {
        LibFarmingStorage.FarmingStorage storage fs = LibFarmingStorage.farmingStorage();
        fs.accumulationEnd = block.timestamp;
        emit LibEvents.AccumulationEventInterrupted();
    }
}
