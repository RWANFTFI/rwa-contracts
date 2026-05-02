// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {LibConstants} from "./diamond/libraries/LibConstants.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IDAO} from "./interfaces/IDAO.sol";
import {IDiamondCut} from "./diamond/interfaces/IDiamondCut.sol";
import {IAdminContract} from "./interfaces/IAdminContract.sol";
import {IGovToken} from "./interfaces/IGovToken.sol";
import {IViewFacet} from "./diamond/interfaces/IViewFacet.sol";

contract DAO is Governor, GovernorSettings, GovernorVotes, GovernorCountingSimple, IDAO {
    bytes32 public constant SERVICE_ROLE = keccak256("SERVICE_ROLE");    
    bytes32 public constant SECURED_ROLE = keccak256("SECURED_ROLE");    
    IGovToken public govToken;
    address diamondContract;

    uint256 lastProposalTime;
    mapping(address => uint256) public lastActivity;

    error UserIsActive();
    error GracePeriod();
    error NoRecentGovernanceActivity();
    error ProposalExpired();

    modifier onlyRole(bytes32 role) {
        if (!IViewFacet(diamondContract).getContracts().adminContract.hasRole(role, msg.sender)) {
            revert IAdminContract.MissingRole(role);
        }
        _;
    }

    constructor(
        address _govToken,
        address diamond,
        uint48 votingDelaySeconds,
        uint32 votingPeriodSeconds,
        uint256 initialProposalThreshold
    )
        Governor("DAO")
        GovernorSettings(votingDelaySeconds, votingPeriodSeconds, initialProposalThreshold)
        GovernorVotes(ERC20Votes(_govToken))
    {
        diamondContract = diamond;
        govToken = IGovToken(_govToken);
    }

    function quorum(uint256 blockNumber) public view override returns (uint256) {
        return ERC20Votes(address(token())).getPastTotalSupply(blockNumber) / 2;
    }

    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function supportsInterface(bytes4 interfaceId) public view override(Governor) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function canExecuteEarly(uint256 proposalId) public view returns (bool) {
        if (super.state(proposalId) != ProposalState.Active) return false;

        (, uint256 forVotes, ) = proposalVotes(proposalId);
        uint256 totalSupply = ERC20Votes(address(token())).getPastTotalSupply(proposalSnapshot(proposalId));
        return forVotes * 2 > totalSupply;
    }

    function state(uint256 proposalId) public view override returns (ProposalState) {
        ProposalState s = super.state(proposalId);
        if (s == ProposalState.Active && canExecuteEarly(proposalId)) {
            return ProposalState.Succeeded;
        }
        return s;
    }

    // Override for allow votes with Succeeded status
    function _castVote(
        uint256 proposalId,
        address account,
        uint8 support,
        string memory reason,
        bytes memory params
    ) internal override returns (uint256) {
        if (block.timestamp > proposalDeadline(proposalId)) revert ProposalExpired();
        _validateStateBitmap(proposalId, _encodeStateBitmap(ProposalState.Active) | _encodeStateBitmap(ProposalState.Succeeded));
        uint256 totalWeight = _getVotes(account, proposalSnapshot(proposalId), params);
        uint256 votedWeight = _countVote(proposalId, account, support, totalWeight, params);

        if (params.length == 0) {
            emit VoteCast(account, proposalId, support, votedWeight, reason);
        } else {
            emit VoteCastWithParams(account, proposalId, support, votedWeight, reason, params);
        }

        _tallyUpdated(proposalId);
        lastActivity[account] = block.timestamp;
        return votedWeight;
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override returns (uint256) {
        lastProposalTime = block.timestamp;
        return super.propose(targets, values, calldatas, description);
    }

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable override onlyRole(SERVICE_ROLE) returns (uint256) {
        return super.execute(targets, values, calldatas, descriptionHash);
    }

    function claimInactive(address user, address recipient) external onlyRole(SECURED_ROLE) {
        uint256 last = lastActivity[user];
        if (block.timestamp < lastProposalTime + LibConstants.VOTES_GRACE_PERIOD) revert GracePeriod();
        if (block.timestamp < last + LibConstants.VOTES_DECAY_TIME) revert UserIsActive();
        if (block.timestamp > lastProposalTime + LibConstants.VOTES_DECAY_TIME) revert NoRecentGovernanceActivity();
        govToken.forceTokenTransfer(user, recipient, govToken.balanceOf(user));
    }

    /// @notice Upgrade Transparent Proxy
    function upgradeProxy(address proxyAdmin, address proxy, address newImplementation) external onlyGovernance {
        require(newImplementation.code.length > 0, "Not a contract");
        ProxyAdmin(proxyAdmin).upgradeAndCall(ITransparentUpgradeableProxy(proxy), newImplementation, "");
    }

    /// @notice Upgrade Transparent Proxy with init call
    function upgradeProxyAndCall(
        address proxyAdmin,
        address proxy,
        address newImplementation,
        bytes calldata data
    ) external onlyGovernance {
        require(newImplementation.code.length > 0, "Not a contract");
        ProxyAdmin(proxyAdmin).upgradeAndCall(ITransparentUpgradeableProxy(proxy), newImplementation, data);
    }

    /// @notice ERC-2535 Diamond cut
    function diamondCut(
        address diamond,
        IDiamondCut.FacetCut[] calldata cut,
        address init,
        bytes calldata initCalldata
    ) external onlyGovernance {
        IDiamondCut(diamond).diamondCut(cut, init, initCalldata);
    }
}
