// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.28;

import {ERC20Upgradeable, IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPool} from "./interfaces/Staking/IPool.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {LibTypes} from "./diamond/libraries/LibTypes.sol";
import {LibErrors} from "./diamond/libraries/LibErrors.sol";
import {LibConstants} from "./diamond/libraries/LibConstants.sol";
import {IAdminContract} from "./interfaces/IAdminContract.sol";
import {ITokenReserve} from "./interfaces/ITokenReserve.sol";
import {IParametersFacet} from "./diamond/interfaces/IParametersFacet.sol";
import {IPaymentFacet} from "./diamond/interfaces/IPaymentFacet.sol";
import {IViewFacet} from "./diamond/interfaces/IViewFacet.sol";
import {IDepositTR} from "./interfaces/IDepositTR.sol";

contract TokenReserve is ERC20Upgradeable, ITokenReserve {
    using SafeERC20 for IERC20;

    uint256 private startPrice;

    uint256 public supply;
    uint256 public availableTokens;
    uint256 public liquidity;

    mapping(uint64 => uint256) public currentStack;
    mapping(uint64 => TokenStack[]) public userTokens;

    IERC20 public payment;
    address public diamondContract;
    address public tokenReserveDeposit;

    modifier payFee() {
        uint256 txFee = IViewFacet(diamondContract).getTxFee();
        if (msg.value != txFee) revert LibErrors.WrongValue();
        address holder = IViewFacet(diamondContract).getHolderAddress();
        (bool success, ) = payable(holder).call{value: msg.value}("");
        require(success, "Send failed");
        _;
    }

    modifier onlyDiamond() {
        if (_msgSender() != diamondContract) revert OnlyDiamond();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address usdt, address diamond, address trd, uint256 predeposit) public initializer {
        if (predeposit == 0) revert ZeroDeposit();
        __ERC20_init("Deflationary Assets", "DA");
        payment = IERC20(usdt);
        payment.approve(diamond, type(uint256).max);
        payment.approve(trd, type(uint256).max);
        diamondContract = diamond;
        tokenReserveDeposit = trd;
        supply = 21_000_000 * 10 ** decimals();
        startPrice = 10 ** decimals();
        payment.safeTransferFrom(_msgSender(), address(this), predeposit);
        _mintSupply(predeposit);
        availableTokens -= predeposit;
        liquidity += predeposit;
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function getPrice() public view returns (uint256 price) {
        if (liquidity == 0) return startPrice;
        else return (liquidity * 10 ** decimals()) / totalSupply();
    }

    /// Deposit USDT with minting DA supply
    /// @param amount usdt to deposit
    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroDeposit();
        payment.safeTransferFrom(_msgSender(), address(this), amount);
        _mintSupply(amount);
        liquidity += amount;
    }

    /// Deposit USDT with claim minted DA supply (only marketing)
    /// @param amount usdt to deposit
    function depositWithClaim(uint256 amount) external onlyDiamond {
        if (amount == 0) return;
        payment.safeTransferFrom(_msgSender(), address(this), amount);
        uint256 minted = _mintSupply(amount);
        liquidity += amount;
        _sendStack(_msgSender(), minted);
    }

    /// Claim DA to recipient (only marketing)
    /// @param to recipient
    /// @param amount DA amount
    function claimReserveTo(address to, uint256 amount) external onlyDiamond {
        if (availableTokens < amount) revert NotEnoughReserveBalance();
        _sendStack(to, amount);
    }

    function changeWallet(address oldOwner, address newOwner) external onlyDiamond {
        uint256 balance = balanceOf(oldOwner);
        if (balance > 0) _transfer(oldOwner, newOwner, balanceOf(oldOwner));
    }

    function _sendStack(address to, uint256 amount) internal {
        uint64 userId = IViewFacet(diamondContract).getUserIdByAddress(to);
        if (userId == 0 && to != diamondContract) revert UnknownUser();
        userTokens[userId].push(TokenStack(amount, block.timestamp, 0, Loan(0, 0)));
        availableTokens -= amount;
        _transfer(address(this), to, amount);
        emit TokenStackCreated(to, amount, userTokens[userId].length - 1, block.timestamp);
    }

    function _mintSupply(uint256 amountUSD) internal returns (uint256 toMint) {
        toMint = (amountUSD * 10 ** decimals()) / getPrice();
        if (supply < toMint) revert NotEnoughSupply();
        supply -= toMint;
        availableTokens += toMint;
        _mint(address(this), toMint);
        emit Deposit(amountUSD, toMint);
    }

    function _reduceArray(StackDecrease[] memory input, uint256 count) private pure returns (StackDecrease[] memory) {
        StackDecrease[] memory decreasedStacks = new StackDecrease[](count);
        for (uint256 ind = 0; ind < count; ind++) {
            decreasedStacks[ind] = input[ind];
        }
        return decreasedStacks;
    }

    function _removeStack(address user, uint64 userId, uint256 amount) private returns (StackDecrease[] memory) {
        uint256 i = currentStack[userId];
        TokenStack[] storage stacks = userTokens[userId];
        StackDecrease[] memory temp = new StackDecrease[](stacks.length - i);
        uint256 count = 0;

        while (amount > 0 && i < stacks.length) {
            TokenStack storage stack = stacks[i];
            if (stack.amount == 0 && stack.loan.amount == 0) {
                i++;
                continue;
            }
            if (stack.amount > amount) {
                temp[count] = StackDecrease(i, amount);
                stack.amount -= amount;
                amount = 0;
            } else {
                temp[count] = StackDecrease(i, stack.amount);
                amount -= stack.amount;
                stack.amount = 0;
                i++;
                if (stack.loan.amount == 0) emit TokenStackLiquidated(user, i - 1);
            }
            count++;
        }
        StackDecrease[] memory decreasedStacks = _reduceArray(temp, count);
        return decreasedStacks;
    }

    function _movePointer(uint64 userId) private {
        for (uint256 i = currentStack[userId]; i < userTokens[userId].length; i++) {
            TokenStack memory stack = userTokens[userId][i];
            if (stack.amount > 0 || stack.loan.amount > 0) return;
            currentStack[userId]++;
        }
    }

    function _getPeriods() private view returns (uint256[4] memory periods) {
        LibTypes.Parameters memory params = IParametersFacet(diamondContract).getParameters();
        periods[0] = params.autoSellPeriods[0];
        periods[1] = periods[0] + params.autoSellPeriods[1];
        periods[2] = periods[1] + params.autoSellPeriods[2];
        periods[3] = periods[2] + params.autoSellPeriods[3];
    }

    function _getPeriodInfo(
        uint64 userId,
        uint256 stackIndex
    ) private view returns (uint256 timeToAutoSale, uint256 period) {
        uint256[4] memory periods = _getPeriods();
        TokenStack memory stack = userTokens[userId][stackIndex];
        uint256 elapsed = block.timestamp - stack.claimedAt;
        if (elapsed <= periods[0]) return (periods[0] - elapsed, 0);
        else if (elapsed <= periods[1]) return (periods[1] - elapsed, 1);
        else if (elapsed <= periods[2]) return (periods[2] - elapsed, 2);
        else if (elapsed <= periods[3]) return (periods[3] - elapsed, 3);
        else return (0, 4);
    }

    /// Sell expired user stacks
    /// @param user user address
    function processExpiredStacks(address user) external {
        if (!IViewFacet(diamondContract).getContracts().adminContract.hasRole(LibConstants.SERVICE_ROLE, _msgSender()))
            revert IAdminContract.MissingRole(LibConstants.SERVICE_ROLE);
        uint64 userId = IViewFacet(diamondContract).getUserIdByAddress(user);
        _processExpiredStacks(user, userId);
    }

    function _processExpiredStacks(address user, uint64 userId) private {
        uint256 i = currentStack[userId];
        TokenStack[] storage stacks = userTokens[userId];
        uint256[4] memory periods = _getPeriods();
        StackDecrease[] memory temp = new StackDecrease[](stacks.length - i);
        uint256 count = 0;
        uint256 totalToSell;
        uint256 totalLoanBurn;
        uint256 liquidityDecrease;

        while (i < stacks.length) {
            TokenStack storage stack = stacks[i];
            uint256 sellInStack = 0;

            if (stack.amount == 0 && stack.loan.amount == 0) {
                i++;
                continue;
            }

            uint256 elapsed = block.timestamp - stack.claimedAt;

            if (elapsed <= periods[0]) {
                break;
            }

            if (elapsed > periods[0] && stack.period < 1) {
                uint256 toBurn = (stack.loan.amount * 25) / 100;
                if (toBurn > 0) {
                    stack.loan.amount -= toBurn;
                    totalLoanBurn += toBurn;
                    liquidityDecrease += (stack.loan.price * toBurn) / 10 ** decimals();
                    emit Burned(user, toBurn, i);
                }

                uint256 toSell = (stack.amount * 25) / 100;
                if (toSell > 0) {
                    sellInStack += toSell;
                    stack.amount -= toSell;
                }

                stack.period++;
            }

            if (elapsed > periods[1] && stack.period < 2) {
                uint256 toBurn = (stack.loan.amount * 40) / 100;
                if (toBurn > 0) {
                    stack.loan.amount -= toBurn;
                    totalLoanBurn += toBurn;
                    liquidityDecrease += (stack.loan.price * toBurn) / 10 ** decimals();
                    emit Burned(user, toBurn, i);
                }

                uint256 toSell = (stack.amount * 40) / 100;
                if (toSell > 0) {
                    sellInStack += toSell;
                    stack.amount -= toSell;
                }

                stack.period++;
            }

            if (elapsed > periods[2] && stack.period < 3) {
                uint256 toBurn = (stack.loan.amount * 50) / 100;
                if (toBurn > 0) {
                    stack.loan.amount -= toBurn;
                    totalLoanBurn += toBurn;
                    liquidityDecrease += (stack.loan.price * toBurn) / 10 ** decimals();
                    emit Burned(user, toBurn, i);
                }

                uint256 toSell = (stack.amount * 50) / 100;
                if (toSell > 0) {
                    sellInStack += toSell;
                    stack.amount -= toSell;
                }

                stack.period++;
            }

            if (elapsed > periods[3] && stack.period < 4) {
                uint256 toBurn = stack.loan.amount;
                if (toBurn > 0) {
                    totalLoanBurn += stack.loan.amount;
                    liquidityDecrease += (stack.loan.price * stack.loan.amount) / 10 ** decimals();
                    stack.loan.amount = 0;
                    emit Burned(user, toBurn, i);
                }

                sellInStack += stack.amount;
                stack.amount = 0;

                stack.period++;
                emit TokenStackLiquidated(user, i);
            }
            if (sellInStack > 0) {
                temp[count] = StackDecrease(i, sellInStack);
                totalToSell += sellInStack;
                count++;
            }
            i++;
        }

        StackDecrease[] memory decreasedStacks = _reduceArray(temp, count);

        if (totalToSell > 0) {
            _forceSell(user, totalToSell, decreasedStacks);
        }
        if (totalLoanBurn > 0) {
            liquidity -= (liquidityDecrease * LibConstants.AUTOSELL_AFTER_FEE) / LibConstants.DENOMINATOR; // Decrease liquidity by paid on expired loans
            _burn(address(this), totalLoanBurn);
        }
        if (totalToSell > 0 || totalLoanBurn > 0) _movePointer(userId);
    }

    function _forceSell(address user, uint256 amount, StackDecrease[] memory decreasedStacks) private {
        uint256 price = getPrice();
        uint256 totalAmount = (amount * price) / 10 ** decimals();
        uint256 amountToPayDirt = (totalAmount * LibConstants.AUTOSELL_AFTER_FEE) / LibConstants.DENOMINATOR;
        uint256 canPay = IPaymentFacet(diamondContract).reduceLimit(user, amountToPayDirt, false, "Forced sell");
        uint256 remainder = amountToPayDirt - canPay;
        if (remainder > 0) IDepositTR(tokenReserveDeposit).depositUSDT(remainder);

        _burn(user, amount);
        liquidity -= amountToPayDirt;
        emit Sold(user, decreasedStacks, amount, canPay, price, true);
    }

    /// Sell DA with reducing marketing limit
    /// @param amount DA to sell
    function sell(uint256 amount) external payable payFee {
        uint64 userId = IViewFacet(diamondContract).getUserIdByAddress(_msgSender());
        _processExpiredStacks(_msgSender(), userId);
        if (amount > balanceOf(_msgSender())) revert NotEnoughBalance();
        uint256 price = getPrice();
        uint256 amountToPayDirt = (amount * price * LibConstants.SELL_AFTER_FEE) /
            (10 ** decimals() * LibConstants.DENOMINATOR);
        uint256 canPay = IPaymentFacet(diamondContract).reduceLimit(
            _msgSender(),
            amountToPayDirt,
            false,
            "Manual sell"
        );
        uint256 remainder = amountToPayDirt - canPay;
        if (remainder > 0) IDepositTR(tokenReserveDeposit).depositUSDT(remainder);

        StackDecrease[] memory decreasedStacks = _removeStack(_msgSender(), userId, amount);
        _movePointer(userId);
        _burn(_msgSender(), amount);
        liquidity -= amountToPayDirt;
        emit Sold(_msgSender(), decreasedStacks, amount, canPay, price, false);
    }

    /// Loan USDT for amount of DA with current price
    /// @param amount DA collateral amount
    /// @param stackIndex token stack
    function loan(uint256 amount, uint256 stackIndex) external payable payFee {
        uint64 userId = IViewFacet(diamondContract).getUserIdByAddress(_msgSender());
        _processExpiredStacks(_msgSender(), userId);
        TokenStack storage ts = userTokens[userId][stackIndex];
        if (ts.amount < amount || ts.amount == 0) revert NotEnoughReserveBalance();
        if (ts.loan.amount > 0) revert UnpaidLoan();
        (uint256 timeToAutoSale, ) = _getPeriodInfo(userId, stackIndex);
        if (timeToAutoSale < LibConstants.LOAN_CUTOFF_PERIOD) revert AutoSaleSoon();
        ts.loan.price = getPrice();
        uint256 usdAmount = (amount * ts.loan.price * LibConstants.AUTOSELL_AFTER_FEE) /
            (10 ** decimals() * LibConstants.DENOMINATOR);
        if (usdAmount == 0) revert ZeroPayment();
        uint256 fee = (usdAmount * IParametersFacet(diamondContract).getLoanFee()) / LibConstants.DENOMINATOR;
        ts.amount -= amount;
        ts.loan.amount += amount;
        _transfer(_msgSender(), address(this), amount);
        IPaymentFacet(diamondContract).depositToTokenReserve(fee);
        IPaymentFacet(diamondContract).depositToUser(_msgSender(), usdAmount - fee, "Loan");
        emit LoanTaken(_msgSender(), stackIndex, amount, usdAmount, ts.loan.price, block.timestamp);
    }

    /// Repay loan
    /// @param amount DA amount
    /// @param stackIndex token stack
    function repay(uint256 amount, uint256 stackIndex) external payable payFee {
        if (amount == 0) revert ZeroPayment();
        uint64 userId = IViewFacet(diamondContract).getUserIdByAddress(_msgSender());
        _processExpiredStacks(_msgSender(), userId);
        TokenStack storage ts = userTokens[userId][stackIndex];
        if (ts.loan.amount == 0) revert LoanPaid();
        if (ts.loan.amount < amount) revert LoanOverpayment();
        uint256 toPay = (amount * ts.loan.price * LibConstants.AUTOSELL_AFTER_FEE) /
            (10 ** decimals() * LibConstants.DENOMINATOR);
        if (toPay == 0) revert ZeroPayment();
        IPaymentFacet(diamondContract).takePayment(_msgSender(), toPay);
        ts.loan.amount -= amount;
        ts.amount += amount;
        _transfer(address(this), _msgSender(), amount);
        emit LoanRepaid(_msgSender(), stackIndex, amount, ts.loan.amount == 0);
    }

    function getStack(address user, uint256 index) external view returns (TokenStack memory) {
        uint64 userId = IViewFacet(diamondContract).getUserIdByAddress(user);
        return userTokens[userId][index];
    }

    function getLastResolvedStack(address user) external view returns (uint256 lastResolvedStack) {
        uint64 userId = IViewFacet(diamondContract).getUserIdByAddress(user);
        return currentStack[userId];
    }

    function getStacksCount(address user) external view returns (uint256 amount) {
        uint64 userId = IViewFacet(diamondContract).getUserIdByAddress(user);
        return userTokens[userId].length;
    }

    function transfer(address to, uint256 amount) public pure override(ERC20Upgradeable, IERC20) returns (bool) {
        revert CannotTransfer();
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public pure override(ERC20Upgradeable, IERC20) returns (bool) {
        revert CannotTransfer();
    }
}
