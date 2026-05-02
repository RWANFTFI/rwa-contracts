// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";

interface IVoucher is IERC721 {
    function safeMint(address to) external returns (uint256);
    function burn(uint256 tokenId) external;
    function send(address to, uint256 tokenId) external;
}