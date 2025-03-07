// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DAO is ReentrancyGuard, Ownable {
    // Struct to store project request details
    struct ProjectRequest {
        uint256 projectId;
        address projectOwner;
        string name;
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        bool isApproved;
        bool isProcessed;
    }

    // Struct to store DAO member details
    struct Member {
        uint256 stakedAmount;
        bool isMember;
    }

    // Mapping to store project requests by project ID
    mapping(uint256 => ProjectRequest) public projectRequests;

    // Mapping to store DAO members by address
    mapping(address => Member) public members;

    // Mapping to track if a member has voted on a project request
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // List of DAO member addresses
    address[] public memberAddresses;

    // Address of the ProjectListing contract
    address public projectListingContract;

    // Minimum stake required to become a DAO member (in wei)
    uint256 public minStakeAmount;

    // Events
    event ProjectRequestReceived(uint256 indexed projectId, address indexed projectOwner, string name, string description);
    event Voted(uint256 indexed projectId, address indexed voter, bool vote);
    event ProjectApproved(uint256 indexed projectId);
    event ProjectRejected(uint256 indexed projectId);
    event NewMember(address indexed member, uint256 stakedAmount); // Add this line

    // Constructor to set the ProjectListing contract address and minimum stake amount
    constructor(address _projectListingContract, uint256 _minStakeAmount) Ownable(msg.sender){
        projectListingContract = _projectListingContract;
        minStakeAmount = _minStakeAmount;
    }

    // Modifier to check if the caller is a DAO member
    modifier onlyMember() {
        require(members[msg.sender].isMember, "Caller is not a DAO member");
        _;
    }

    // Function to become a DAO member by staking ETH
    function joinDAO() external payable nonReentrant {
        require(msg.value >= minStakeAmount, "Insufficient stake amount");
        require(!members[msg.sender].isMember, "Already a DAO member");

        // Add the user as a DAO member
        members[msg.sender] = Member({
            stakedAmount: msg.value,
            isMember: true
        });

        // Add the member's address to the list
        memberAddresses.push(msg.sender);

        // Emit event
        emit NewMember(msg.sender, msg.value); // This line now works
    }

    // Function to receive project requests from ProjectListing.sol
    function receiveProjectRequest(uint256 projectId, address projectOwner, string memory name, string memory description) external {
        require(msg.sender == projectListingContract, "Caller is not the ProjectListing contract");

        // Create a new project request
        projectRequests[projectId] = ProjectRequest({
            projectId: projectId,
            projectOwner: projectOwner,
            name: name,
            description: description,
            yesVotes: 0,
            noVotes: 0,
            isApproved: false,
            isProcessed: false
        });

        // Emit event
        emit ProjectRequestReceived(projectId, projectOwner, name, description);
    }

    // Function for DAO members to vote on a project request
    function voteOnProject(uint256 projectId, bool vote) external onlyMember {
        require(!projectRequests[projectId].isProcessed, "Project request already processed");
        require(!hasVoted[projectId][msg.sender], "Already voted on this project");

        // Update vote count
        if (vote) {
            projectRequests[projectId].yesVotes++;
        } else {
            projectRequests[projectId].noVotes++;
        }

        // Mark the member as having voted
        hasVoted[projectId][msg.sender] = true;

        // Emit event
        emit Voted(projectId, msg.sender, vote);
    }

    // Function to process a project request after voting ends
    function processProjectRequest(uint256 projectId) external onlyOwner {
        require(!projectRequests[projectId].isProcessed, "Project request already processed");

        // Check if the project has a majority of yes votes
        if (projectRequests[projectId].yesVotes > projectRequests[projectId].noVotes) {
            projectRequests[projectId].isApproved = true;
            emit ProjectApproved(projectId);
        } else {
            emit ProjectRejected(projectId);
        }

        // Mark the project request as processed
        projectRequests[projectId].isProcessed = true;
    }

    // Function to update the ProjectListing contract address (only callable by the owner)
    function updateProjectListingContract(address newProjectListingContract) external onlyOwner {
        projectListingContract = newProjectListingContract;
    }

    // Function to update the minimum stake amount (only callable by the owner)
    function updateMinStakeAmount(uint256 newAmount) external onlyOwner {
        minStakeAmount = newAmount;
    }
}
