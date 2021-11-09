// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract EthLottery {
    /**
        Fund the lottery initially.
        Start the lottery.
        Enter the lottery.
            Validate the tickets. (Python API)
            Adjust the prizes.    
        End the lottery:
            Insert the lottery result.
            Select winners. (Python API)
            Send funds to the winners.
        Withdraw the earnings.
     */

    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNERS
    }

    struct Player {
        address playerAddress;
        string ticket;
    }

    uint256 public ticketValue;
    uint256 public firstPrize; // 55% of the total fund.
    uint256 public secondPrize; // 20% of the total fund.
    uint256 public thirdPrize; // 10% of the total fund.
    uint256 earnings; // 15% of the total fund. (5% gas expenses).

    Player[] public players;
    //mapping(address => string[]) public addressToTickets;

    LOTTERY_STATE public lotteryState;

    constructor() {
        ticketValue = 10**15; //in wei (0.001 ETH)
        lotteryState = LOTTERY_STATE.CLOSED;
    }

    function enterLottery(string memory lottoTicket) public payable {
        // Buy a lotto ticket.

        //Requires that the lottery is open.
        require(
            lotteryState == LOTTERY_STATE.OPEN,
            "The lottery hasn't started yet"
        );
        //Requires that the user pays the correct amount for the lotto ticket
        require(msg.value == ticketValue, "Send the correct amount");

        //Requires a valid ticket
        require(validateTicket(lottoTicket), "Not a valid ticket.");

        //Add the user to the players array.
        players.push(Player(msg.sender, lottoTicket));

        //recalculate the rewards and earnings.
        calculatePrizesAndEarnings();
    }

    function validateTicket(string memory lottoTicket)
        public
        view
        returns (bool)
    {
        //The ticket should be like : XXXXXXXXXXXX where X is a number.

        bytes memory bytesLottoTicket = bytes(lottoTicket);

        if (bytesLottoTicket.length != 12) return false; //Validate the length of the string.

        //Validate that the string is numeric, using  the ASCII code (HEX) of each char.
        for (uint256 i = 0; i < bytesLottoTicket.length; i++) {
            bytes1 char = bytesLottoTicket[i];
            if (char < 0x30 || char > 0x39) return false;
        }

        return true;
    }

    function calculatePrizesAndEarnings() internal {
        uint256 totalBalance = address(this).balance;

        firstPrize = totalBalance * 0.55;
        secondPrize = totalBalance * 0.20;
        thirdPrize = totalBalance * 0.10;
        earnings = totalBalance * 0.15;
    }

    function startLottery() public {
        // Start lottery.
        //Note: Only the owner can start the lottery.
        lotteryState = LOTTERY_STATE.OPEN;
    }

    function insertLottoResult(bytes32 lottoResult) public {
        //Inserts the numbers of the lottery result.
        //Note: only the owner can insert the lotto result.
    }

    function selectWinners() internal {
        // Select the winners after the numbers are selected.
    }

    function transferToWinners() internal {
        //Transfers assets to the winners.
    }

    function endLottery() public {
        // End the lottery.
        //Note: only the owner can end the lottery.
        lotteryState = LOTTERY_STATE.CLOSED;
        players = new Player[](0);
    }

    function withdrawEarnings() public payable {
        //Withdraw the earnings of the lotto.
        //Note: only the owner can withdraw the funds of the contract.
    }
}
