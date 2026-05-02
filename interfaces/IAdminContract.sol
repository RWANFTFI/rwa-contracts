// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import {IAccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/IAccessControlEnumerable.sol";


interface IAdminContract is IAccessControlEnumerable {
    error MissingRole(bytes32);

    function isAdminContract() external pure returns (bool);
}