// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EthLottery is Ownable, ChainlinkClient {
    using Chainlink for Chainlink.Request;
    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNERS
    }

    enum PRIZE_TYPE {
        FIRST,
        SECOND,
        THIRD
    }

    struct Player {
        address payable playerAddress;
        string ticketNumber;
    }

    struct WinnerTicket {
        string ticketNumber;
        uint256 ticketDate;
    }

    address private oracle;
    bytes32 private numberOfWinnersJobId;
    bytes32 private getWinnersJobId;
    uint256 private fee;
    IERC20 linkToken;

    uint256 public ticketValue;
    uint256 totalPrizes;
    uint256 public firstPrize; // 50% of the total fund.
    uint256 public secondPrize; // 20% of the total fund.
    uint256 public thirdPrize; // 10% of the total fund.
    uint256 public lastNWinners;
    int256 public currentWinnerIndex;
    uint256 reserve; // 20% of the total fund

    string[] public currentTickets;
    Player[] public currentPlayers;
    WinnerTicket[] public lottoResults;
    LOTTERY_STATE public lotteryState;

    constructor(
        address _oracle,
        bytes32 _numberOfWinnersJobId,
        bytes32 _getWinnersJobId,
        uint256 _ticketValue,
        address _linkTokenAddress
    ) {
        oracle = _oracle;
        numberOfWinnersJobId = _numberOfWinnersJobId;
        getWinnersJobId = _getWinnersJobId;
        lotteryState = LOTTERY_STATE.CLOSED;
        ticketValue = _ticketValue; //in wei (0.001 ETH) 10**15
        linkToken = IERC20(_linkTokenAddress);
        lastNWinners = 0;
        fee = 0.1 * 10**18;
        setPublicChainlinkToken();
    }

    //0. Fund lottery first time.
    function fundLottery(
        uint256 pFPrize,
        uint256 pSPrize,
        uint256 pTPrize
    ) public payable onlyOwner {
        require(
            pFPrize + pSPrize + pTPrize == 100,
            "The sum of the parameters should be 100"
        );
        uint256 amount = msg.value;
        firstPrize = (amount * pFPrize) / 100;
        secondPrize = (amount * pSPrize) / 100;
        thirdPrize = (amount * pTPrize) / 100;

        totalPrizes = firstPrize + secondPrize + thirdPrize;
    }

    // 1. Start lottery
    function startLottery() public onlyOwner {
        // Start lottery.
        //Note: Only the owner can start the lottery.
        lotteryState = LOTTERY_STATE.OPEN;
    }

    // 2. Tickets sale
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

        currentPlayers.push(Player(payable(msg.sender), lottoTicket));
        currentTickets.push(lottoTicket);
    }

    function validateTicket(string memory lottoTicket)
        internal
        pure
        returns (bool)
    {
        bytes memory bytesLottoTicket = bytes(lottoTicket);

        if (bytesLottoTicket.length != 12) return false; //Validate the length of the string.
        //Validate that the string is numeric, using  the ASCII code (HEX) of each char.

        for (uint256 i = 0; i < bytesLottoTicket.length; i++) {
            bytes1 char = bytesLottoTicket[i];
            if (char < 0x30 || char > 0x39) return false;
        }

        return true;
    }

    // 3. Close lottery.
    function endLottery(string memory winnerTicket) public onlyOwner {
        // End the lottery.
        //Note: only the owner can end the lottery.
        require(validateTicket(winnerTicket), "Not a valid ticket.");
        lottoResults.push(WinnerTicket(winnerTicket, block.timestamp));
        lotteryState = LOTTERY_STATE.CLOSED;

        delete currentPlayers;
        delete currentTickets;
    }

    // 4. Get Winners
    function requestNumberOfWinners()
        public
        onlyOwner
        returns (bytes32 requestId)
    {
        Chainlink.Request memory request = buildChainlinkRequest(
            numberOfWinnersJobId,
            address(this),
            this.fulfillNumberOfWinners.selector
        );

        currentTickets = [
            "621601750774",
            "601501750774",
            "621501750774",
            "925641558974",
            "424601750970",
            "921601840678"
        ];
        request.add("username", "supercow");
        request.add("password", "12345678");
        request.add("winner_ticket", "621601750774");
        request.addStringArray("tickets", currentTickets);

        return sendChainlinkRequestTo(oracle, request, fee);
    }

    function fulfillNumberOfWinners(bytes32 _requestId, uint256 _lastNWinners)
        public
        recordChainlinkFulfillment(_requestId)
    {
        lastNWinners = _lastNWinners;
    }

    function requestWinnerData(int256 _winnerIndex)
        public
        onlyOwner
        returns (bytes32 requestId)
    {
        Chainlink.Request memory request = buildChainlinkRequest(
            getWinnersJobId,
            address(this),
            this.fulfillWinnerData.selector
        );

        currentTickets = [
            "621601750774",
            "601501750774",
            "621501750774",
            "925641558974",
            "424601750970",
            "921601840678"
        ];
        request.add("username", "supercow");
        request.add("password", "12345678");
        request.add("winner_ticket", "621601750774");
        request.addStringArray("tickets", currentTickets);
        request.addInt("winner_index", _winnerIndex);

        return sendChainlinkRequestTo(oracle, request, fee);
    }

    function fulfillWinnerData(bytes32 _requestId, int256 _winnerIndex)
        public
        recordChainlinkFulfillment(_requestId)
    {
        currentWinnerIndex = _winnerIndex;
    }

    function calculatePrizesAndReserve() internal {
        uint256 totalBalance = address(this).balance;

        firstPrize = (totalBalance * 50) / 100; //  50%
        secondPrize = (totalBalance * 20) / 100; //  20%
        thirdPrize = (totalBalance * 10) / 100; //  10%
        reserve = (totalBalance * 20) / 100; //  20%
    }

    function withdrawLink(uint256 amount) public onlyOwner {
        require(linkToken.transfer(msg.sender, amount), "Transfer failed");
    }

    /*
    function getWinners() public {
        // Select the winners after the numbers are selected.
    }
    /*
    function transferToWinners() internal {
        //Transfers assets to the winners.
    }

    function withdrawEarnings() public payable onlyOwner {
        //Withdraw the earnings of the lotto.
        //Note: only the owner can withdraw the funds of the contract.
    }*/
}
