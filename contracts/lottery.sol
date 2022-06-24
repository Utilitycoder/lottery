// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

error Lottery__sendMoreEth();
error Lottery__MoneyNotSent();
error Lottery__NotAvailable();
error Lottery__UpkeepNotNeeded(uint balance, uint numPlayers, uint raffleState);

/**@title A sample Raffle Contract
 * @author Lawal Abubakar
 * @notice This contract is for creating a sample Lottery contract
 * @dev This implements the Chainlink VRF Version 2
 */
contract Lottery is VRFConsumerBaseV2, KeeperCompatibleInterface {
    //  Types
    enum RaffleState {
        OPEN,
        CALCULATING
    }
    // State Variable
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint private immutable i_entranceFee;
    address payable[] private s_players;
    bytes32 private immutable i_gaslane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint16 private constant NUM_WORDS = 1;

    // Lottery variables
    address private s_recentWinner;
    RaffleState private s_raffleState;
    uint private s_lastTimeStamp;
    uint private immutable i_interval;

    event newPlayer(uint indexed _amount, address indexed _player);
    event requestRandomWinner(uint indexed requestId);
    event PastWinners(address indexed winnners);

    constructor(
        address vrfCoordinatorV2,
        uint _entranceFee,
        bytes32 gaslane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = _entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gaslane = gaslane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    function enterLottery() public payable {
        if (msg.value < i_entranceFee) revert Lottery__sendMoreEth();
        if (s_raffleState != RaffleState.OPEN) revert Lottery__NotAvailable();
        s_players.push(payable(msg.sender));
        emit newPlayer(msg.value, msg.sender);
    }

    function checkUpkeep(
        bytes memory /*checkData*/
    )
        public
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = (address(this).balance > 0);
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
    }

    function performUpkeep(
        bytes calldata /* PerformData */
    ) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Lottery__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        uint requestId = i_vrfCoordinator.requestRandomWords(
            i_gaslane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit requestRandomWinner(requestId);
    }

    function fulfillRandomWords(
        uint, /*requestId*/
        uint[] memory randomWords
    ) internal override {
        uint indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) revert Lottery__MoneyNotSent();
        emit PastWinners(winner);
    }

    // function withdrawPrice(){}

    // Getter / View Functions
    function getEntranceFee() public view returns (uint) {
        return i_entranceFee;
    }

    function getPlayer(uint index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns(RaffleState) {
        return s_raffleState;
    }

    function getNumOfPlayers() public view returns (uint) {
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns (uint) {
        return s_lastTimeStamp;
    }



    function getRequestConfirmation() public pure returns(uint) {
        return REQUEST_CONFIRMATIONS;
    }

    function getNumWords() public pure returns(uint) {
        return NUM_WORDS;
    }
}
