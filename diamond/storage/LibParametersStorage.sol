// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibTypes} from "../libraries/LibTypes.sol";

library LibParametersStorage {
    bytes32 constant PARAMETERS_STORAGE_POSITION = keccak256("diamond.standard.parameters.storage");

    struct ParametersStorage {
        LibTypes.Parameters parameters;
        mapping(LibTypes.ParameterField => uint256[22]) minParamValues;
        mapping(LibTypes.ParameterField => uint256[22]) maxParamValues;
        mapping(LibTypes.NftField => uint256[11]) minNftValues;
        mapping(LibTypes.NftField => uint256[11]) maxNftValues;
        mapping(LibTypes.GiftField => uint256[]) minGiftValues;
        mapping(LibTypes.GiftField => uint256[]) maxGiftValues;
        LibTypes.NFT[] regularTypes;
        LibTypes.GiftNFT[] giftTypes;
        uint256 txFeeMin;
        uint256 txFeeMax;
    }

    function parametersStorage() internal pure returns (ParametersStorage storage ps) {
        bytes32 position = PARAMETERS_STORAGE_POSITION;
        // assigns struct storage slot to the storage position
        assembly {
            ps.slot := position
        }
    }
}
