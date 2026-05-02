// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibTypes} from "../libraries/LibTypes.sol";

interface IResolverFacet {
    function getUserTokenInfo(uint64 user) external view returns (LibTypes.UserTokenInfo memory info);

    function getUsersTokenInfo(uint64[] memory user) external view returns (LibTypes.UserTokenInfo[] memory info);

    function processRegularBought(
        uint64 user,
        uint32 level
    ) external returns (uint256 tokenId, uint256 limit, uint256 price, uint256 autoBuys);

    function processRegularUpgrade(
        uint64 user,
        uint32 level
    ) external returns (uint256 tokenId, uint256 limit, uint256 price, uint256 autoBuys);

    function processGiftUpgrade(
        uint64 user,
        uint32 level
    ) external returns (uint256 tokenId, uint256 limit, uint256 price, uint256 autoBuys);
}
