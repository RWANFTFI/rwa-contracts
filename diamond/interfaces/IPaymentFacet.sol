// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibTypes} from "../libraries/LibTypes.sol";

interface IPaymentFacet {
    function reduceLimit(
        address user,
        uint256 amount,
        bool deductFee,
        string memory description
    ) external returns (uint256 payed);

    function takePayment(address user, uint256 amount) external;

    function depositToTokenReserve(uint256 amount) external;

    function depositToUser(address user, uint256 amount, string memory source) external;
}
