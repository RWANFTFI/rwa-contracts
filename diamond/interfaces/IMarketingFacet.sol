// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IMarketingFacet {
    function createUser(address user) external returns (uint64 userId);
}
