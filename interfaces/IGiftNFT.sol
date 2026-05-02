// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";

interface IGiftNFT is IERC721 {
    struct NFT {
        uint256 limit;
        uint256 innerPercent;
    }
    function sendGift(address to, uint256 tokenId) external;
    function safeMint(address to) external returns (uint256);
    // function balanceOf(address owner) external returns (uint256);
    function burn(address owner, uint256 tokenId) external;
    function setBaseURL(string memory _newBaseURL) external;
    function getNextTokenId() external returns(uint256);
}