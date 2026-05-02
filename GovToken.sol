// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {IAdminContract} from "./interfaces/IAdminContract.sol";
import {IViewFacet} from "./diamond/interfaces/IViewFacet.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract GovToken is ERC20, ERC20Votes {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address diamondContract;

    mapping(address => bool) public allowedSender;

    error OnlyDAO();
    error SenderNotAllowed();

    modifier onlyDAO() {
        if (_msgSender() != IViewFacet(diamondContract).getDaoAddress()) revert OnlyDAO();
        _;
    }

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        address diamond
    ) ERC20(name_, symbol_) EIP712(name_, "1") {
        super._update(address(0), _msgSender(), initialSupply);
        _delegate(_msgSender(), _msgSender());
        diamondContract = diamond;
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function setAllowedSender(address user, bool allowed) external {
        if (!IViewFacet(diamondContract).getContracts().adminContract.hasRole(ADMIN_ROLE, _msgSender()))
            revert IAdminContract.MissingRole(ADMIN_ROLE);
        allowedSender[user] = allowed;
    }

    function forceTokenTransfer(address from, address to, uint256 amount) external onlyDAO {
        _transfer(from, to, amount);
    }

    // OVERRIDES

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        if (_msgSender() != IViewFacet(diamondContract).getDaoAddress()) {
            if (from != address(0)) {
                if (!allowedSender[from]) {
                    revert SenderNotAllowed();
                }
            }
        }
        _delegate(to, to);
        super._update(from, to, value);
    }

    function delegate(address delegatee) public pure override {
        revert("Unsupported");
    }

    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure override {
        revert("Unsupported");
    }
}
