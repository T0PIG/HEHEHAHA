
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Reputation-based Voting with Weighted Power
 * @dev A smart contract that implements a voting system where voting power is determined by user reputation
 */
contract Project {
    
    // Struct to represent a proposal
    struct Proposal {
        uint256 id;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 deadline;
        bool executed;
        address proposer;
        mapping(address => bool) hasVoted;
        mapping(address => uint256) voterWeight;
    }
    
    // Struct to track user reputation
    struct User {
        uint256 reputation;
        uint256 participationCount;
        bool isRegistered;
    }
    
    // State variables
    mapping(address => User) public users;
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;
    uint256 public constant MIN_REPUTATION = 10;
    uint256 public constant VOTING_DURATION = 7 days;
    address public admin;
    
    // Events
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCasted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ReputationUpdated(address indexed user, uint256 newReputation);
    event UserRegistered(address indexed user);
    
    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }
    
    modifier onlyRegistered() {
        require(users[msg.sender].isRegistered, "User must be registered");
        _;
    }
    
    modifier validProposal(uint256 _proposalId) {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        require(block.timestamp <= proposals[_proposalId].deadline, "Voting period has ended");
        require(!proposals[_proposalId].executed, "Proposal already executed");
        _;
    }
    
    constructor() {
        admin = msg.sender;
        // Register admin with initial reputation
        users[admin] = User({
            reputation: 100,
            participationCount: 0,
            isRegistered: true
        });
    }
    
    /**
     * @dev Core Function 1: Register a new user and assign initial reputation
     * @param _initialReputation Initial reputation score for the user
     */
    function registerUser(uint256 _initialReputation) external {
        require(!users[msg.sender].isRegistered, "User already registered");
        require(_initialReputation >= MIN_REPUTATION, "Initial reputation too low");
        
        users[msg.sender] = User({
            reputation: _initialReputation,
            participationCount: 0,
            isRegistered: true
        });
        
        emit UserRegistered(msg.sender);
    }
    
    /**
     * @dev Core Function 2: Create a new proposal for voting
     * @param _description Description of the proposal
     */
    function createProposal(string memory _description) external onlyRegistered returns (uint256) {
        require(users[msg.sender].reputation >= MIN_REPUTATION, "Insufficient reputation to create proposal");
        require(bytes(_description).length > 0, "Proposal description cannot be empty");
        
        uint256 proposalId = proposalCount;
        Proposal storage newProposal = proposals[proposalId];
        
        newProposal.id = proposalId;
        newProposal.description = _description;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.deadline = block.timestamp + VOTING_DURATION;
        newProposal.executed = false;
        newProposal.proposer = msg.sender;
        
        proposalCount++;
        
        // Increase proposer's participation count and reputation
        users[msg.sender].participationCount++;
        _updateReputation(msg.sender, 5); // Bonus for creating proposals
        
        emit ProposalCreated(proposalId, msg.sender, _description);
        return proposalId;
    }
    
    /**
     * @dev Core Function 3: Cast a vote on a proposal with weighted power based on reputation
     * @param _proposalId ID of the proposal to vote on
     * @param _support True for supporting the proposal, false for opposing
     */
    function castVote(uint256 _proposalId, bool _support) external onlyRegistered validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.hasVoted[msg.sender], "User has already voted on this proposal");
        require(users[msg.sender].reputation >= MIN_REPUTATION, "Insufficient reputation to vote");
        
        // Calculate voting weight based on reputation (square root for balanced weighting)
        uint256 votingWeight = _calculateVotingWeight(users[msg.sender].reputation);
        
        // Record the vote
        proposal.hasVoted[msg.sender] = true;
        proposal.voterWeight[msg.sender] = votingWeight;
        
        if (_support) {
            proposal.forVotes += votingWeight;
        } else {
            proposal.againstVotes += votingWeight;
        }
        
        // Update user's participation and reputation
        users[msg.sender].participationCount++;
        _updateReputation(msg.sender, 2); // Small bonus for participating in voting
        
        emit VoteCasted(_proposalId, msg.sender, _support, votingWeight);
    }
    
    /**
     * @dev Calculate voting weight based on reputation using square root for balanced scaling
     * @param _reputation User's reputation score
     * @return Calculated voting weight
     */
    function _calculateVotingWeight(uint256 _reputation) internal pure returns (uint256) {
        if (_reputation < MIN_REPUTATION) return 0;
        
        // Using a simplified square root approximation for voting weight
        // Weight = sqrt(reputation) + 1 to ensure minimum weight of 1
        uint256 weight = 1;
        uint256 temp = _reputation;
        
        // Simple square root approximation
        while (temp >= 4) {
            weight++;
            temp = temp / 4;
        }
        
        return weight;
    }
    
    /**
     * @dev Update user reputation with bounds checking
     * @param _user Address of the user
     * @param _bonus Reputation bonus to add
     */
    function _updateReputation(address _user, uint256 _bonus) internal {
        uint256 newReputation = users[_user].reputation + _bonus;
        
        // Cap reputation at 1000 to prevent excessive concentration of power
        if (newReputation > 1000) {
            newReputation = 1000;
        }
        
        users[_user].reputation = newReputation;
        emit ReputationUpdated(_user, newReputation);
    }
    
    // View functions
    function getProposalResults(uint256 _proposalId) external view returns (
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 deadline,
        bool executed,
        address proposer
    ) {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[_proposalId];
        
        return (
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.deadline,
            proposal.executed,
            proposal.proposer
        );
    }
    
    function getUserInfo(address _user) external view returns (
        uint256 reputation,
        uint256 participationCount,
        bool isRegistered,
        uint256 votingWeight
    ) {
        User storage user = users[_user];
        return (
            user.reputation,
            user.participationCount,
            user.isRegistered,
            _calculateVotingWeight(user.reputation)
        );
    }
    
    function hasUserVoted(uint256 _proposalId, address _user) external view returns (bool) {
        require(_proposalId < proposalCount, "Invalid proposal ID");
        return proposals[_proposalId].hasVoted[_user];
    }
    
    // Admin functions
    function adjustUserReputation(address _user, uint256 _newReputation) external onlyAdmin {
        require(users[_user].isRegistered, "User not registered");
        require(_newReputation <= 1000, "Reputation cannot exceed 1000");
        
        users[_user].reputation = _newReputation;
        emit ReputationUpdated(_user, _newReputation);
    }
