// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibTreeStorage} from "../storage/LibTreeStorage.sol";
import {LibMarketingStorage} from "../storage/LibMarketingStorage.sol";
import {LibResolverStorage} from "../storage/LibResolverStorage.sol";
import {LibMarketingLogic} from "../libraries/LibMarketingLogic.sol";
import {LibParametersLogic} from "../libraries/LibParametersLogic.sol";
import {LibFarmingLogic} from "../libraries/LibFarmingLogic.sol";
import {LibTypes} from "../libraries/LibTypes.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IERC173} from "../interfaces/IERC173.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IAdminContract} from "../../interfaces/IAdminContract.sol";
import {IVoucher} from "../../interfaces/IVoucher.sol";
import {INFT} from "../../interfaces/INFT.sol";
import {IGiftNFT} from "../../interfaces/IGiftNFT.sol";
import {ITokenReserve} from "../../interfaces/ITokenReserve.sol";

contract DiamondInit {
    struct DiamondArgs {
        address paymentToken;
        address adminContract;
        address regularContract;
        address ambContract;
        address giftContract;
        address voucherContract;
        address tokenReserve;
        address dao;
        string version;
    }

    struct MarketingArgs {
        uint256 txFee;
        uint256 miningDelay;
        address treeRoot;
        address holder;
    }

    struct ParametersArgs {
        LibTypes.NFT[] nfts;
        LibTypes.RangesNFT[] nftRanges;
        LibTypes.GiftNFT[] gifts;
        LibTypes.RangesGift[] giftRanges;
    }

    // You can add parameters to this function in order to pass in
    // data to set your own state variables
    function init(DiamondArgs calldata dArgs, MarketingArgs calldata mArgs, ParametersArgs calldata pArgs) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
        ds.domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Marketing")),
                keccak256(bytes(dArgs.version)),
                block.chainid,
                address(this)
            )
        );

        ds.contracts.adminContract = IAdminContract(dArgs.adminContract);
        ds.contracts.regularContract = INFT(dArgs.regularContract);
        ds.contracts.ambContract = INFT(dArgs.ambContract);
        ds.contracts.giftContract = IGiftNFT(dArgs.giftContract);
        ds.contracts.voucherContract = IVoucher(dArgs.voucherContract);
        ds.contracts.tokenReserve = ITokenReserve(dArgs.tokenReserve);
        ds.contracts.paymentToken = IERC20(dArgs.paymentToken);
        ds.contracts.dao = dArgs.dao;
        ds.signatureVerify = true;
        _initMarketing(ds, mArgs);
        _initTree();
        LibParametersLogic.init(pArgs.nfts, pArgs.nftRanges, pArgs.gifts, pArgs.giftRanges);
        LibFarmingLogic.init(mArgs.miningDelay);

        // add your own state variables
        // EIP-2535 specifies that the `diamondCut` function takes two optional
        // arguments: address _init and bytes calldata _calldata
        // These arguments are used to execute an arbitrary function using delegatecall
        // in order to set state variables in the diamond during deployment or an upgrade
        // More info here: https://eips.ethereum.org/EIPS/eip-2535#diamond-interface
    }

    function _initTree() private {
        LibTreeStorage.TreeStorage storage ts = LibTreeStorage.treeStorage();
        ts.maxDepth = 22;
    }

    function _initMarketing(LibDiamond.DiamondStorage storage ds, MarketingArgs memory mArgs) private {
        LibMarketingStorage.MarketingStorage storage ms = LibMarketingStorage.marketingStorage();
        LibResolverStorage.ResolverStorage storage rs = LibResolverStorage.resolverStorage();

        ms.nextId = 1;
        ms.txFee = mArgs.txFee;
        ms.holder = mArgs.holder;
        uint64 userId = LibMarketingLogic.register(ms, mArgs.treeRoot, 0, true);
        uint256 tokenId = ds.contracts.regularContract.safeMint(mArgs.treeRoot);
        rs.registeredTokens[tokenId] = LibTypes.RegisteredNFT({
            owner: userId,
            level: 0,
            typeNFT: LibTypes.TypeNFT.REGULAR,
            isActive: true
        }); // Fake nft without limit for initialize tree root
        ds.contracts.paymentToken.approve(address(ds.contracts.tokenReserve), type(uint256).max);
        rs.owners[userId] = tokenId;
        rs.minted[0]++;
    }
}
