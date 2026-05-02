// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract AmbNFT is ERC721 {
    using Strings for uint256;
    uint256 private _nextTokenId = 1;
    string private baseURL;
    address public diamondAddress;

    error OnlyDiamond();


    constructor(address diamond, string memory name, string memory symbol, string memory uri) ERC721(name, symbol) {
        diamondAddress = diamond;
        baseURL = uri;
    }

    modifier onlyDiamond() {
        if (_msgSender() != address(diamondAddress)) revert OnlyDiamond();
        _;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);

        string memory metadataURI = string(abi.encodePacked(baseURL, "/", tokenId.toString(), "/metadata.json"));
        return metadataURI;
    }

    function setBaseURL(string memory _newBaseURL) external onlyDiamond {
        baseURL = _newBaseURL;
    }

    function safeMint(address to) public onlyDiamond returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    function send(address to, uint256 tokenId) external onlyDiamond {
        address from = ownerOf(tokenId);
        _safeTransfer(from, to, tokenId);
    }

    function _update(address to, uint256 tokenId, address auth) internal override onlyDiamond returns (address) {
        return super._update(to, tokenId, auth);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId) public view override(ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
