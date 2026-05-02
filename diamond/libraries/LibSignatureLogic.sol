// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibConstants} from "./LibConstants.sol";
import {LibDiamond} from "./LibDiamond.sol";
import {LibEvents} from "./LibEvents.sol";
import {LibErrors} from "./LibErrors.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

library LibSignatureLogic {
    using ECDSA for bytes32;

    bytes32 public constant GIFT_REQUEST_TYPEHASH =
        keccak256("GiftNFT(address sender,address to,uint256 tokenId,uint256 nonce)");
    bytes32 public constant WITHDRAW_REQUEST_TYPEHASH =
        keccak256("Withdraw(address sender,uint256 amount,uint256 nonce)");
    bytes32 public constant SELL_BUSINESS_REQUEST_TYPEHASH =
        keccak256("SellBusiness(address sender,address newOwner,uint256 nonce)");
    bytes32 public constant TRANSFER_VOUCHER_REQUEST_TYPEHASH =
        keccak256("TransferVoucher(address sender,address to,uint256 tokenId,uint256 nonce)");
    bytes32 public constant TRANSFER_ACCUMULATIVE_REQUEST_TYPEHASH =
        keccak256("TransferAccumulative(address sender,address to,uint256 amount,uint256 deadline,uint256 nonce)");

    function domainSeparatorV4() internal view returns (bytes32) {
        return LibDiamond.diamondStorage().domainSeparator;
    }

    function _toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) private pure returns (bytes32 digest) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, hex"19_01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            digest := keccak256(ptr, 0x42)
        }
    }

    function _hashTypedDataV4(bytes32 structHash) private view returns (bytes32) {
        return _toTypedDataHash(domainSeparatorV4(), structHash);
    }

    function verify(bytes32 structHash, bytes calldata signature) internal {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (!ds.signatureVerify) return;

        bytes32 digest = _hashTypedDataV4(structHash);
        if (ds._usedHashes[digest]) revert LibErrors.SignatureReplay();
        ds._usedHashes[digest] = true;
        address signer = digest.recover(signature);
        if (!ds.contracts.adminContract.hasRole(LibConstants.SIGNER_ROLE, signer)) revert LibErrors.WrongSignature();
    }

    function signatureVerifyStatus(bool status) internal {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.signatureVerify = status;
        emit LibEvents.SignatureVerificationStatus(status);
    }
}
