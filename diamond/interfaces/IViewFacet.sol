// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibTypes} from "../libraries/LibTypes.sol";

interface IViewFacet {
    function getTxFee() external view returns (uint256);
    function getHolderAddress() external view returns (address);
    function getUserAddressById(uint64 id) external view returns(address);
    function getUserIdByAddress(address user) external view returns(uint64);
    function getDaoAddress() external view returns(address);
    function getContracts() external view returns(LibTypes.Contracts memory);
}
