// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IDAO {
    enum ProposalType {
        ExternalCall,
        UpdateParameters
    }

    struct Receipt {
        bool hasVoted;
        bool support;
        uint256 votes;
    }
}
