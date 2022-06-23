// SPDX-License-Identifier: MIT

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.4;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

error sendMoreEth();

contract lottery is VRFConsumerBaseV2 {
    // State Variable
    uint private immutable i_entranceFee;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gaslane;

    event newPlayer(uint indexed _amount, address indexed _player);

    constructor(
        address vrfCoordinatorV2,
        uint _entranceFee,
        bytes32 gaslane
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = _entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gaslane = gaslane;
    }

    function enterLottery() public payable {
        if (msg.value < i_entranceFee) revert sendMoreEth();
        s_players.push(payable(msg.sender));
        emit newPlayer(msg.value, msg.sender);
    }

    function createRandomWinner() external {
        
    }

    function fulfillRandomWords(uint requestId, uint[] memory randomWords)
        internal
        override
    {}

    // function withdrawPrice(){}

    // Getter functions
    function getEntranceFee() public view returns (uint) {
        return i_entranceFee;
    }

    function getPlayer(uint index) public view returns (address) {
        return s_players[index];
    }
}
