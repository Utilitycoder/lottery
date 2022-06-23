// SPDX-License-Identifier: MIT

// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.7;

error sendMoreEth();

contract lottery {
    // State Variable
    uint private immutable i_entranceFee;
    address payable[] private s_players;

    event newPlayer(uint indexed _amount, address indexed _player);

    constructor(uint _entranceFee) {
        i_entranceFee = _entranceFee;
    }
    function enterLottery() public payable {
        if (msg.value < i_entranceFee) revert sendMoreEth();
        s_players.push(payable(msg.sender));
        emit newPlayer(msg.value, msg.sender);
    }

    function createRandomWinner() external {

    }

    function fulfillRandomWords() internal override {

    }

    function withdrawPrice(){}

    // Getter functions
    function getEntranceFee() public view returns(uint) {
        return i_entranceFee;
    }

    function getPlayer(uint index) public view return(address) {
        return s_players[index];
    }
}