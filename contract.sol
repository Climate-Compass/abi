// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Chainlink, ChainlinkClient} from "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

contract RestrictedAccess is ChainlinkClient, ConfirmedOwner {
   using Chainlink for Chainlink.Request;

    uint256 public volume;
    bytes32 private jobId;
    uint256 private fee;
    uint256 private base;
    string[] private challengeNames;

    event RequestVolume(bytes32 indexed requestId, uint256 volume);

    struct Challenge {
        string name;
        string apiUrl;
        uint256 lastExecutionTime;
        uint256 delay;
        uint256 totalFunds;
        bool executed; // Track if the challenge has been executed
        string[] answers;
    }

    struct UserChallenge {
        mapping(string => uint256) challengeNumbers; // Challenge name to number mapping
        string[] ownedChallenges; // List of owned challenges
    }

    mapping(address => UserChallenge) private userChallenges;

    mapping(string => Challenge) public challenges;

    // List of users who have been assigned challenges
    address[] private users;

    mapping(address => bool) public allowedAddresses;

    event AddressAdded(address indexed _address);
    event AddressRemoved(address indexed _address);

    modifier onlyAllowed() {
        require(allowedAddresses[msg.sender], "You are not allowed to perform this action");
        _;
    }

    constructor() ConfirmedOwner(msg.sender) {
        _setChainlinkToken(0x5576815a38A3706f37bf815b261cCc7cCA77e975);
        _setChainlinkOracle(0x849c5ED5a80F5B408Dd4969b78c2C8fdf0565Bfe/*0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD*/);
        jobId = "7d80a6386ef543a3abb52817f6707e3b"; // string
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    function addAddress(address _address) public onlyOwner {
        allowedAddresses[_address] = true;
    }

    function removeAddress(address _address) public onlyOwner {
        allowedAddresses[_address] = false;
    }

    function createChallenge(
        string memory _name,
        string memory _apiUrl,
        uint256 _delay,
        uint256 _totalFunds,
        string[] memory _answers
    ) public onlyAllowed {
        Challenge storage challenge = challenges[_name];
        challenge.name = _name;
        challenge.apiUrl = _apiUrl;
        challenge.answers = _answers;
        challenge.delay = _delay;
        challenge.totalFunds = _totalFunds;
        challenge.lastExecutionTime = block.timestamp;
        challenge.executed = false;

        challengeNames.push(_name);

 //       finishChallenge(_name);
    }

    modifier delayedExecution(string memory _name) {
        require(!challenges[_name].executed, "Challenge has already been executed");
        require(block.timestamp >= challenges[_name].lastExecutionTime + challenges[_name].delay, "Function called too soon");
        _;
        challenges[_name].executed = true;
    }

    
    function finishChallenge(string memory _name) public delayedExecution(_name) {
        // pay all the right answers with token
        // call api to know the right answer
        // W.I.P. should use ChainLink
        
        // so the correct answer is temporary
        distributeFunds("The temperature will rise.");
    }

    function distributeFunds(string memory _name) public {
        Challenge storage challenge = challenges[_name];
        require(challenge.executed, "Challenge has not been executed yet");
        require(challenge.totalFunds > 0, "No funds to distribute");

        uint256 totalFunds = challenge.totalFunds;
        challenge.totalFunds = 0; // Reset total funds to prevent reentrancy

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 userProportion = userChallenges[user].challengeNumbers[_name];
            if (userProportion > 0) {
                uint256 userShare = (totalFunds * userProportion) / getChallengeNumberSum(_name);
                (bool success, ) = user.call{value: userShare}("");
                require(success, "Transfer failed");
            }
        }
    }

    function assignChallengeToUser(address _user, string memory _challengeName, uint256 _number) internal {
        require(!challenges[_challengeName].executed, "Challenge has already been executed");

        UserChallenge storage userChallenge = userChallenges[_user];
        
        // Add the user to the users array if they are not already in it
        if (userChallenge.ownedChallenges.length == 0) {
            users.push(_user);
        }
        
        // Add the challenge to the user's list if not already present
        if (userChallenge.challengeNumbers[_challengeName] == 0) {
            userChallenge.ownedChallenges.push(_challengeName);
        }
        
        userChallenge.challengeNumbers[_challengeName] = _number;
    }

    function buyChallenge(string memory _name) public payable {
        require(!challenges[_name].executed, "Challenge has already been executed");
        require(msg.value > 0, "Must send ETH to buy the challenge");

        uint256 newNumber = msg.value;
        
        // Assign the challenge to the user with the value sent as the number
        assignChallengeToUser(msg.sender, _name, newNumber);
    }

    function getUserChallenges(address _user) public view returns (string[] memory) {
        return userChallenges[_user].ownedChallenges;
    }

    function getChallengeNumberSum(string memory _challengeName) public view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            sum += userChallenges[user].challengeNumbers[_challengeName];
        }
        return sum;
    }

    function getAllChallengeNames() public view returns (string[] memory) {
        return challengeNames;
    }
}

