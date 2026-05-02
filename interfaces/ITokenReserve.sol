// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITokenReserve is IERC20 {
    struct Loan {
        uint256 amount;
        uint256 price;
    }

    struct TokenStack {
        uint256 amount;
        uint256 claimedAt;
        uint256 period;
        Loan loan;
    }

    struct StackDecrease {
        uint256 stackIndex;
        uint256 amount;
    }
    
    event TokenStackCreated(address indexed user, uint256 amount, uint256 stackIndex, uint256 timestamp);
    event TokenStackLiquidated(address indexed user, uint256 stackIndex);

    event LoanTaken(address indexed user, uint256 stackIndex, uint256 amount, uint256 paid, uint256 price, uint256 timestamp);
    event LoanRepaid(address indexed user, uint256 stackIndex, uint256 amount, bool full);
    event Burned(address indexed user, uint256 amount, uint256 stackIndex);
    event Deposit(uint256 amountUSDT, uint256 amountDA);

    event Sold(address indexed user, StackDecrease[] decreasedStacks, uint256 tokenAmount, uint256 usdAmount, uint256 price, bool isAuto);

    error NotEnoughReserveBalance();
    error NotEnoughBalance();
    error NotEnoughSupply();
    error UnpaidLoan();
    error LoanPaid();
    error LoanOverpayment();
    error AutoSaleSoon();
    error OnlyDiamond();
    error CannotTransfer();
    error UnknownUser();
    error ZeroDeposit();    
    error ZeroPayment();

    function getPrice() external view returns (uint256 price);
    function deposit(uint256 amount) external;
    function claimReserveTo(address to, uint256 amount) external;
    function depositWithClaim(uint256 amount) external;
    function changeWallet(address oldOwner, address newOwner) external;
}