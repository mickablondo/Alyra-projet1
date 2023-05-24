// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

/**
 * @title Projet 1 - formation Alyra - Contrat de vote pour une petite organisation.
 * @dev Gestion d'un système de vote dont les électeurs peuvent réaliser des propositions.
 * @author Mickael Blondeau - Promotion Buterin 2023
 */
contract Voting is Ownable {
    // structure représentant un électeur
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    // structure représentant une proposition
    struct Proposal {
        string description;
        uint voteCount;
    }

    // les différents états d'un vote
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    uint public winningProposalId;
    WorkflowStatus public workflowStatus;
    mapping(address => Voter) voters;
    Proposal[] proposals;

    // déclaration des événements
    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    // ---------- Modifiers ----------

    /**
     * @dev La personne qui interroge doit être dans la whitelist
     */
    modifier onlyVoters() {
        require(voters[msg.sender].isRegistered, "Forbidden access, you're not a voter !");
        _;
    }

    /**
     * @dev On vérifie que le tableau de proposition n'est pas vide.
     */
    modifier notEmptyProposals() {
        require(proposals.length > 0, "No proposals sended.");
        _;
    }

    /**
     * @dev On vérifie que la proposition existe
     */
    modifier shouldIdProposalExists(uint _proposalId) {
        require(_proposalId < proposals.length, "This proposal doesn't exist.");
        _;
    }

    // ---------- Actions d'administration ----------

    /**
     * @dev L'administrateur du vote enregistre une liste blanche d'électeurs identifiés par leur adresse Ethereum.
     */
    function registerVoter(address _address) external onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Wrong step to register a new voter !");
        require(!voters[_address].isRegistered, "Already registered.");
        
        voters[_address].isRegistered = true;
        emit VoterRegistered(_address);
    }

    /**
     * @dev L'administrateur du vote commence la session d'enregistrement de la proposition.
     */
    function startProposalsRegistration() external onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Wrong step to start the registration of proposals !");
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    /**
     * @dev L'administrateur de vote met fin à la session d'enregistrement des propositions.
     */
    function stopProposalsRegistration() external onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Wrong step to stop the registration of proposals !");
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    }

    /**
     * @dev L'administrateur du vote commence la session de vote.
     */
    function startVotingSession() external onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, "Wrong step to start voting !");
        workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    /**
     * @dev L'administrateur du vote met fin à la session de vote.
     */
    function stopVotingSession() external onlyOwner {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Wrong step to stop voting !");
        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    /**
     * @dev L'administrateur du vote comptabilise les votes.
     */
    function tallyVotes() external onlyOwner notEmptyProposals {
        require(workflowStatus == WorkflowStatus.VotingSessionEnded, "Wrong step to tally the votes !");
        uint _winnerId;

        for(uint i=0; i<proposals.length; i++) {
            if(proposals[i].voteCount > proposals[_winnerId].voteCount) {
                _winnerId = i;
            }
        }
        winningProposalId = _winnerId;

        workflowStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
    }

    // ---------- Actions des électeurs ----------

    /**
     * @dev Les électeurs inscrits sont autorisés à enregistrer leurs propositions pendant que la session d'enregistrement est active.
     */
    function addProposal(string calldata _description) external onlyVoters {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals can't be sent now.");
        require(bytes(_description).length > 0, "Can't send empty proposal.");

        Proposal memory proposal;
        proposal.description = _description;
        proposals.push(proposal);
        emit ProposalRegistered(proposals.length-1);
    }

    /**
     * @dev Les électeurs inscrits votent pour leur proposition préférée.
     */
    function addVote(uint _proposalId) external onlyVoters notEmptyProposals shouldIdProposalExists(_proposalId) {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Votes can't be sent now.");
        require(!voters[msg.sender].hasVoted, "You can only vote once.");

        proposals[_proposalId].voteCount++;
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposalId;
        emit Voted(msg.sender, _proposalId);
    }

    /**
     * @dev Chaque électeur peut voir les votes des autres. 
     */
    function getVote(address _address) external view onlyVoters returns (uint) {
        require(voters[_address].isRegistered, "This address can't vote.");
        require(voters[_address].hasVoted, "This address didn't vote.");
        require(workflowStatus >= WorkflowStatus.VotingSessionStarted, "Voting session has not started.");

        return voters[_address].votedProposalId;
    }

    /**
     * @dev Chaque électeur peut prendre connaissance d'une proposition.
     */
    function getProposal(uint _proposalId) external view onlyVoters notEmptyProposals shouldIdProposalExists(_proposalId) returns (string memory) {
        return proposals[_proposalId].description;
    }

    // ---------- Action pour tous ----------

    /**
     * @dev Tout le monde peut vérifier les derniers détails de la proposition gagnante.
     */
    function getWinnerProposal() external view notEmptyProposals returns (string memory) {
        require(workflowStatus == WorkflowStatus.VotesTallied, "Please, wait the end of the tally.");
        return proposals[winningProposalId].description;
    }
}