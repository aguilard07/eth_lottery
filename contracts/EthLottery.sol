// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract EthLottery {
    /**
        Fund the lottery initially.
        Start the lottery.
        Enter the lottery.
            Validate the tickets.
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

    uint256 public ticketValue;
    uint256 public firstPrize; // 55% of the total fund.
    uint256 public secondPrize; // 20% of the total fund.
    uint256 public thirdPrize; // 10% of the total fund.
    uint256 earnings; // 15% of the total fund. (5% gas expenses).

    mapping(address => string[]) public addressToTickets;

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
    }

    function validateTicket(string memory lottoTicket)
        public
        view
        returns (bool)
    {
        //The ticket should be like : XX-XX-XX-XX-XX-XX where X is a number.
        bytes memory bytesLottoTicket = bytes(lottoTicket);

        if (bytesLottoTicket.length != 17) return false; //Validate the length of the string.

        //Validate that the string is numeric, using  the ASCII code (HEX) of each char.
        for (uint256 i; i < bytesLottoTicket.length; i++) {
            bytes1 char = bytesLottoTicket[i];
            if (char != 0x2D) {
                // 0x2D in ASCII is "-"
                if (char < 0x30 || char > 0x39) return false;
            }
        }

        return true;
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
    }

    function withdrawEarnings() public {
        //Withdraw the earnings of the lotto.
        //Note: only the owner can withdraw the funds of the contract.
    }
}
