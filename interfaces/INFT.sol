// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";

interface INFT is IERC721 {
    function safeMint(address to) external returns (uint256);
    function send(address to, uint256 tokenId) external;
    function setBaseURL(string memory _newBaseURL) external;
}