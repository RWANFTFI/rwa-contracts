// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

contract AdminContract is AccessControlEnumerable {
    bytes32 public constant SECURED_ROLE = keccak256("SECURED_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SERVICE_ROLE = keccak256("SERVICE_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setRoleAdmin(ADMIN_ROLE, SECURED_ROLE);
        _setRoleAdmin(SERVICE_ROLE, SECURED_ROLE);
        _setRoleAdmin(SIGNER_ROLE, SECURED_ROLE);
        _setRoleAdmin(MINTER_ROLE, SECURED_ROLE);
    }

    function isAdminContract() external pure returns (bool) {
        return true;
    }
}
