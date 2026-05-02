// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibTypes} from "../libraries/LibTypes.sol";

interface IParametersFacet {
    function getParameters() external view returns (LibTypes.Parameters memory);

    function getRegular(uint32 level) external view returns (LibTypes.NFT memory);

    function getLoanFee() external view returns (uint256);
}
