// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

error Lottery__sendMoreEth();
error Lottery__MoneyNotSent();
error Lottery__NotAvailable();
error Lottery__UpkeepNotNeeded(uint balance, uint numPlayers, uint LotteryState);

/**@title A sample Raffle Contract
 * @author Lawal Abubakar
 * @notice This contract is for creating a sample Lottery contract
 * @dev This implements the Chainlink VRF Version 2
 */
contract Lottery is VRFConsumerBaseV2, KeeperCompatibleInterface {
    //  Types
    enum LotteryState {
        OPEN,
        CALCULATING
    }
    /** State Variable */ 
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint private immutable i_entranceFee;
    address payable[] private s_players;
    bytes32 private immutable i_gaslane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint16 private constant NUM_WORDS = 1;

    /** Lottery variables */
    address private s_recentWinner;
    LotteryState private s_lotteryState;
    uint private s_lastTimeStamp;
    uint private immutable i_interval;

    /** Events */
    event newPlayer(uint indexed _amount, address indexed _player);
    event PastWinners(address indexed winnners);

    /**
    * @notice constructor to initialize some state variables
    * @param vrfCoordinatorV2 address of chainlink vrf
    * @param gaslane needed as a variable for VRF requestRandomword Method (from Chainlink account)
    * @param subscriptionId same as gaslane
    * @param callbackGasLimit same as gaslane
    * @param interval required to operate chainlink keeper
    */
    constructor(
        address vrfCoordinatorV2,
        uint _entranceFee,
        bytes32 gaslane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        /** Initialize state variables with arguments */
        i_entranceFee = _entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gaslane = gaslane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lotteryState = LotteryState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }
    /** @notice This functions lets people participate in the lottery 
    */
    function enterLottery() public payable {
        // user can't send less than entraceFee
        if (msg.value < i_entranceFee) revert Lottery__sendMoreEth(); 
        // Lottery must be ON to participate
        if (s_lotteryState != LotteryState.OPEN) revert Lottery__NotAvailable();
        // Add address of new player to s_player array
        s_players.push(payable(msg.sender));
        // Tell the world someone just joined the ongoing lottery and how much they participated with
        emit newPlayer(msg.value, msg.sender);
    }
    /** @notice Function highlighted conditions that must be met before chaink VRF give us a random number
    * @return upkeepNeeded The state of the contract before calling VRF
    */
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
        // Lottery is Open
        bool isOpen = (LotteryState.OPEN == s_lotteryState);
        // difference between last timestamp of VRF execution and current timestamp is greater than interval
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        // Guarantee that players have deposited money to play
        bool hasPlayers = (s_players.length > 0);
        // Guarantee that this contract has money.
        bool hasBalance = (address(this).balance > 0);
        // upkeep is required if all the above conditions are met before running chainlink keeper
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
    }

    /**
     * @dev Once `checkUpkeep` is returning `true`, this function is called
     * and it kicks off a Chainlink VRF call to get a random winner.
     */
    function performUpkeep(
        bytes calldata /* PerformData */
    ) external override {
        // Store the boolean received from checkUpkeep Function
        (bool upkeepNeeded, ) = checkUpkeep("");
        // Revert if upkeepNeeded is false.
        if (!upkeepNeeded) {
            revert Lottery__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint(s_lotteryState)
            );
        }
        // Change lottery state 
        s_lotteryState = LotteryState.CALCULATING;
        // save what is returned from VRF in requestId
        uint requestId = i_vrfCoordinator.requestRandomWords(
            i_gaslane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
    }

    function fulfillRandomWords(
        uint, /*requestId*/
        uint[] memory randomWords
    ) internal override {
        uint indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_lotteryState = LotteryState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) revert Lottery__MoneyNotSent();
        emit PastWinners(winner);
    }

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

    function getLotteryState() public view returns(LotteryState) {
        return s_lotteryState;
    }

    function getNumOfPlayers() public view returns (uint) {
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns (uint) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint) {
        return i_interval;
    }

    function getRequestConfirmation() public pure returns(uint) {
        return REQUEST_CONFIRMATIONS;
    }

    function getNumWords() public pure returns(uint) {
        return NUM_WORDS;
    }
}
