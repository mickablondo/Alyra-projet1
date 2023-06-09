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
    address[] voterAddresses;

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
    modifier onlyNotEmptyProposals() {
        require(proposals.length > 0, "No proposals sended.");
        _;
    }

    /**
     * @dev On vérifie que la proposition existe
     * @param _proposalId id de la proposition
     */
    modifier shouldIdProposalExists(uint _proposalId) {
        require(_proposalId < proposals.length, "This proposal doesn't exist.");
        _;
    }

    // ---------- Actions d'administration ----------

    /**
     * @dev L'administrateur du vote enregistre une liste blanche d'électeurs identifiés par leur adresse Ethereum.
     * @param _address adresse ehtereum d'un électeur
     */
    function registerVoter(address _address) external onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Wrong step to register a new voter !");
        require(!voters[_address].isRegistered, "Already registered.");
        
        voters[_address].isRegistered = true;
        voterAddresses.push(_address);
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
    function tallyVotes() external onlyOwner onlyNotEmptyProposals {
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

    /**
     * @dev L'administrateur ré-initialise une nouvelle session de vote.
     * La session peut être ré-initialisée dans 2 cas : 
     *  - s'il y a eu des propositions, des votes et que l'état est à VotesTallied
     *  - s'il n'y a pas eu de proposition et que l'état est au-moins à ProposalsRegistrationEnded
     */
    function resetVoteSession() external onlyOwner {
        require(workflowStatus == WorkflowStatus.VotesTallied // suffisant car on arrive à cet état seulement s'il y a eu des propositions
                || (workflowStatus >= WorkflowStatus.ProposalsRegistrationEnded && proposals.length == 0) // permet de ne pas bloquer la session courante si 0 proposition
            , "Please, wait the end of the current voting session.");

        workflowStatus = WorkflowStatus.RegisteringVoters;
        winningProposalId = 0;
        delete proposals;
        for (uint i=0; i < voterAddresses.length; i++) {
            delete voters[voterAddresses[i]];
        }
        delete voterAddresses;

        emit WorkflowStatusChange(WorkflowStatus.VotesTallied, WorkflowStatus.RegisteringVoters);
    }

    // ---------- Actions des électeurs ----------

    /**
     * @dev Les électeurs inscrits sont autorisés à enregistrer leurs propositions pendant que la session d'enregistrement est active.
     * @param _description contenu de la proposition
     */
    function addProposal(string calldata _description) external onlyVoters {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Proposals can't be sent now.");
        require(bytes(_description).length > 0, "Can't send empty proposal.");

        for (uint i=0; i < proposals.length; i++) {
            require(keccak256(abi.encodePacked(proposals[i].description)) != keccak256(abi.encodePacked(_description)), "This proposal already exists.");
        }

        proposals.push(Proposal(_description, 0));
        emit ProposalRegistered(proposals.length-1);
    }

    /**
     * @dev Les électeurs inscrits votent pour leur proposition préférée.
     * @param _proposalId id de la proposition votée
     */
    function addVote(uint _proposalId) external onlyVoters onlyNotEmptyProposals shouldIdProposalExists(_proposalId) {
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Votes can't be sent now.");
        require(!voters[msg.sender].hasVoted, "You can only vote once.");

        proposals[_proposalId].voteCount++;
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = _proposalId;
        emit Voted(msg.sender, _proposalId);
    }

    /**
     * @dev Chaque électeur peut voir les votes des autres. 
     * @param _address adresse de l'électeur dont on souhaite connaître le vote
     * @return l'id de la proposition
     */
    function getVote(address _address) external view onlyVoters returns (uint) {
        require(voters[_address].isRegistered, "This address can't vote.");
        require(voters[_address].hasVoted, "This address didn't vote.");
        require(workflowStatus >= WorkflowStatus.VotingSessionStarted, "Voting session has not started.");

        return voters[_address].votedProposalId;
    }

    /**
     * @dev Chaque électeur peut prendre connaissance d'une proposition.
     * @param _proposalId id de la proposition
     * @return description de la proposition demandée
     */
    function getProposal(uint _proposalId) external view onlyVoters onlyNotEmptyProposals shouldIdProposalExists(_proposalId) returns (string memory) {
        return proposals[_proposalId].description;
    }

    // ---------- Action pour tous ----------

    /**
     * @dev Tout le monde peut vérifier les derniers détails de la proposition gagnante.
     * @return la description de la proposition gagnante
     */
    function getWinnerProposal() external view onlyNotEmptyProposals returns (string memory) {
        require(workflowStatus == WorkflowStatus.VotesTallied, "Please, wait the end of the tally.");
        return proposals[winningProposalId].description;
    }
}