// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19; // TODO A CHANGER !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

/**
 * @title Projet 1 - formation Alyra - Contrat de vote pour une petite organisation.
 * @dev Gestion d'un système de vote dont les électeurs peuvent réaliser des propositions.
 * @author Mickael Blondeau
 */
contract Voting is Ownable {
    uint public winningProposalId;

    // structure représentant un votant
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }
    mapping(address => Voter) private voters;

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
    // valeur par défaut : RegisteringVoters
    // visibilité publique pour connaître l'étape en cours
    WorkflowStatus public workflowStatus;
    Proposal[] proposals;

    // déclaration des événements
    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted(address voter, uint proposalId);

    // ---------- Modifiers ----------

    /**
     * @dev La personne qui interroge doit être dans la whitelist ///////// TODO ou l'administrateur ???????????????????????
     */
    modifier onlyVoters() {
        require(voters[msg.sender].isRegistered, "Caller is not a voter !");
        _;
    }

    /**
     * @dev On vérifie que le tableau de proposition n'est pas vide.
     */
    modifier notEmptyProposals() {
        require(proposals.length>0, "No proposals sended.");
        _;
    }

    // ---------- Action d'administration ----------

    /**
     * @notice L'administrateur du vote enregistre une liste blanche d'électeurs identifiés par leur adresse Ethereum.
     * @param _address l'adresse ethereum de l'électeur à ajouter
     */
    function registerVoter(address _address) external onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Wrong step to register a new voter !"); // TODO MODIFIER avec startProposalsRegistration ???????????
        voters[_address].isRegistered = true;
        emit VoterRegistered(_address);
    }

    /**
     * @notice L'administrateur du vote commence la session d'enregistrement de la proposition.
     */
    function startProposalsRegistration() external onlyOwner {
        require(workflowStatus == WorkflowStatus.RegisteringVoters, "Wrong step to start the registration of proposals !");
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(WorkflowStatus.RegisteringVoters, WorkflowStatus.ProposalsRegistrationStarted);
    }

    /**
     * @notice L'administrateur de vote met fin à la session d'enregistrement des propositions.
     */
    function stopProposalsRegistration() external onlyOwner { /////////// TODO SI 0 proposition ???????????????????
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationStarted, "Wrong step to stop the registration of proposals !");
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationStarted, WorkflowStatus.ProposalsRegistrationEnded);
    }

    /**
     * @notice L'administrateur du vote commence la session de vote.
     */
    function startVotingSession() external onlyOwner {
        require(workflowStatus == WorkflowStatus.ProposalsRegistrationEnded, "Wrong step to start voting !");
        workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(WorkflowStatus.ProposalsRegistrationEnded, WorkflowStatus.VotingSessionStarted);
    }

    /**
     * @notice L'administrateur du vote met fin à la session de vote.
     */
    function stopVotingSession() external onlyOwner { /////////// TODO SI 0 vote ???????????????????
        require(workflowStatus == WorkflowStatus.VotingSessionStarted, "Wrong step to stop voting !");
        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionStarted, WorkflowStatus.VotingSessionEnded);
    }

    /**
     * @notice L'administrateur du vote comptabilise les votes.
     */
    function tallyVotes() external onlyOnwer {
        require(workflowStatus == WorkflowStatus.VotingSessionEnded, "Wrong step to tally the votes !");
        // TODO !!!!!!!!!!!!!!!!!!!!!!!! La proposition qui obtient le plus de voix l'emporte.
        workflowStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(WorkflowStatus.VotingSessionEnded, WorkflowStatus.VotesTallied);
    }

    // ---------- Actions des électeurs ----------

    /**
     * @notice Les électeurs inscrits sont autorisés à enregistrer leurs propositions pendant que la session d'enregistrement est active. ==> vérif non vide !
     */
    // TODO

    /**
     * @notice Les électeurs inscrits votent pour leur proposition préférée. ==> vérif : non supérieur à array.length
     */
    // TODO

    /**
     * @notice Chaque électeur peut voir les votes des autres. 
     */
    // TODO

    // ---------- Actions sur les proposals ----------

    /**
     * @notice Chaque électeur peut prendre connaissance d'une proposition.
     * @param _id identifiant de la proposition
     * @return proposal la description de la proposition
     */
    function getProposal(uint _id) external view onlyVoters notEmptyProposals returns (string memory) {
        return proposals[_id];
    }

    /**
     * @notice Tout le monde peut vérifier les derniers détails de la proposition gagnante.
     * @return proposal la description de la proposition gagnante
     */
    function getWinnerProposal() external view notEmptyProposals returns (string memory) {
        require(workflowStatus == WorkflowStatus.VotesTallied, "Please, wait the end of the tally.");
        return proposals[winningProposalId];
    }

    /* // TODO à vérifier
✔️ Le vote n'est pas secret pour les utilisateurs ajoutés à la Whitelist
✔️ Chaque électeur peut voir les votes des autres
✔️ Le gagnant est déterminé à la majorité simple
✔️ La proposition qui obtient le plus de voix l'emporte.
✔️ N'oubliez pas que votre code doit inspirer la confiance et faire en sorte de respecter les ordres déterminés!
    */
}