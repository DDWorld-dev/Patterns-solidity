// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IVotes.sol";

contract Governor {
    
    struct ProposalVote {
        uint againstVotes;
        uint forVotes;
        uint abstainVotes;
        mapping(address => bool) hasVoted;
    }

    struct Proposal {
        uint votingStarts;
        uint votingEnds;
        bool executed;
        bool canceled;
    }

    enum VoteType { Against, For, Abstain }
    enum ProposalState { Pending, Active, Succeeded, Defeated, Execute, Cancele }
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => ProposalVote) public proposalVotes;

    uint public constant VOTING_DELAY = 10;
    uint public constant VOTING_DURATION = 60;

    event ProposalAdded(uint proposalId);
    IVotes public immutable token;

    constructor(IVotes tokenAddress) {
        token = tokenAddress;
    }
    
    function _getVotes(address account, uint256 blockNumber, bytes memory) internal view virtual  returns (uint256) {
        return token.getPastVotes(account, blockNumber);
    }
    function propose(
        address targets,
        uint values,
        bytes calldata calldatas,
        string calldata description
    ) external returns(uint256) {
        require(
            _getVotes(msg.sender, block.number - 1, "") >= 0,
            "Governor: proposer votes not anougth"
        );

        uint256 proposalId = hashProposal(
            targets, values, calldatas, keccak256(bytes(description))
        );

        require(proposals[proposalId].votingStarts == 0, "proposal already exists");

        proposals[proposalId] = Proposal({
            votingStarts: block.timestamp + VOTING_DELAY,
            votingEnds: block.timestamp + VOTING_DELAY + VOTING_DURATION,
            executed: false,
            canceled: false
        });

        emit ProposalAdded(proposalId);

        return proposalId;
    }
   

    function execute(
        address targets,
        uint values,
        bytes calldata calldatas,
        string calldata description
    ) external returns(bytes memory) {
        uint256 proposalId = hashProposal(
            targets, values, calldatas, keccak256(bytes(description))
        );

        require(state(proposalId) == ProposalState.Succeeded, "invalid state");

        proposals[proposalId].executed = true;

       
        (bool success, bytes memory resp) = targets.call{value: values}(calldatas);
        require(success, "tx failed");

        return resp;
    }
    function _cancel(
        address targets,
        uint values,
        bytes calldata calldatas,
        string calldata description
    ) internal virtual returns (uint256) {
        uint256 proposalId = hashProposal(
            targets, values, calldatas, keccak256(bytes(description))
        );

        ProposalState status = state(proposalId);

        require(
            status == ProposalState.Defeated   ,
            "Governor: proposal not active"
        );
        proposals[proposalId].canceled = true;

        return proposalId;
    }

    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support
    ) internal virtual  {
        ProposalVote storage proposalVote = proposalVotes[proposalId];

        require(!proposalVote.hasVoted[account], "GovernorVotingSimple: vote already cast");
        require(state(proposalId) == ProposalState.Active, "vote not currently active");

        uint256 weight = _getVotes(account, block.number-1, "");

        if (support == uint8(VoteType.Against)) {
            proposalVote.againstVotes += weight;
        } else if (support == uint8(VoteType.For)) {
            proposalVote.forVotes += weight;
        } else if (support == uint8(VoteType.Abstain)) {
            proposalVote.abstainVotes += weight;
        } else {
            revert("invalid value for enum VoteType");
        }
        proposalVote.hasVoted[account] = true;
    }

    function state(uint proposalId) public view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        ProposalVote storage proposalVote = proposalVotes[proposalId];

        require(proposal.votingStarts > 0, "proposal doesnt exist");

        if (proposal.executed) {
            return ProposalState.Execute;
        }

        
        if (proposal.canceled) {
            return ProposalState.Cancele;
        }

        if (block.timestamp < proposal.votingStarts) {
            return ProposalState.Pending;
        }

        if(block.timestamp >= proposal.votingStarts &&
            proposal.votingEnds > block.timestamp) {
            return ProposalState.Active;
        }

        if(proposalVote.forVotes > proposalVote.againstVotes) {
            return ProposalState.Succeeded;
        } else {
            return ProposalState.Defeated;
        }
    }

    function hashProposal(
        address targets,
        uint values,
        bytes calldata calldatas,
        bytes32 description
    ) internal pure returns(uint256) {
        return uint256(keccak256(abi.encode(
            targets, values, calldatas, description
        )));
    }

    receive() external payable {}
}


