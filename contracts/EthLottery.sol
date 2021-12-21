// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EthLottery is Ownable, ChainlinkClient {
    using Chainlink for Chainlink.Request;

    uint256 FIRST_PRIZE_PERCENT = 50;
    uint256 SECOND_PRIZE_PERCENT = 20;
    uint256 THIRD_PRIZE_PERCENT = 10;
    uint256 EARNINGS_PRIZE_PERCENT = 20;

    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNERS
    }

    enum TICKET_MATCHES {
        FOUR,
        FIVE,
        SIX
    }

    struct Player {
        address payable playerAddress;
        string ticketNumber;
    }

    struct Winner {
        address payable playerAddress;
        string ticketNumber;
        uint256 lottoDate;
        TICKET_MATCHES nMatches;
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
    int256[] public winnersIndexes;

    uint256 earnings; // 20% of the total fund

    uint256 internal fourMatchesGroup;
    uint256 internal fiveMatchesGroup;
    uint256 internal sixMatchesGroup;

    string[] public currentTickets;
    Player[] public currentPlayers;
    Winner[] public currentWinners;
    Winner[] public allWinners;
    WinnerTicket[] public lottoResults;
    LOTTERY_STATE public lotteryState;

    event TicketBought(address playerAddress, string ticketNumber);
    event WinnerFound(address winnerAddress, uint256 nAsserts);
    event PrizeSent(address winnerAddress, uint256 nAsserts, uint256 amount);

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
        require(lotteryState == LOTTERY_STATE.CLOSED);
        lotteryState = LOTTERY_STATE.OPEN;
        fourMatchesGroup = 0;
        fiveMatchesGroup = 0;
        sixMatchesGroup = 0;
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
        emit TicketBought(msg.sender, lottoTicket);
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
    function endLottery(
        string memory _winnerTicket,
        string memory _username,
        string memory _password
    ) public onlyOwner {
        // End the lottery.
        //Note: only the owner can end the lottery.
        require(lotteryState == LOTTERY_STATE.OPEN);
        require(validateTicket(_winnerTicket), "Not a valid ticket.");

        lottoResults.push(WinnerTicket(_winnerTicket, block.timestamp));
        lotteryState = LOTTERY_STATE.CALCULATING_WINNERS;

        //Getting winners
        requestNumberOfWinners(_winnerTicket, _username, _password);
        getWinnersData(_winnerTicket, _username, _password);
        sendPrizesToWinners();
        recalculatePrizes();
        resetLists();
        lotteryState = LOTTERY_STATE.CLOSED;
    }

    // 4. Get Winners
    function requestNumberOfWinners(
        string memory _winnerTicket,
        string memory _username,
        string memory _password
    ) internal returns (bytes32 requestId) {
        Chainlink.Request memory request = buildChainlinkRequest(
            numberOfWinnersJobId,
            address(this),
            this.fulfillNumberOfWinners.selector
        );

        /* currentTickets = [
            "621601750774",
            "601501750774",
            "621501750774",
            "925641558974",
            "424601750970",
            "921601840678"
        ];
        request.add("username", "supercow");
        request.add("password", "12345678");
        request.add("winner_ticket", "621601750774");*/

        request.addStringArray("tickets", currentTickets);

        return sendChainlinkRequestTo(oracle, request, fee);
    }

    function fulfillNumberOfWinners(bytes32 _requestId, uint256 _lastNWinners)
        public
        recordChainlinkFulfillment(_requestId)
    {
        lastNWinners = _lastNWinners;
    }

    function requestWinnerData(
        int256 _winnerIndex,
        string memory _winnerTicket,
        string memory _username,
        string memory _password
    ) internal returns (bytes32 requestId) {
        require(lastNWinners > 0, "There's no winners in the lottery.");
        Chainlink.Request memory request = buildChainlinkRequest(
            getWinnersJobId,
            address(this),
            this.fulfillWinnerData.selector
        );

        /*/ currentTickets = [
            "621601750774",
            "601501750774",
            "621501750774",
            "925641558974",
            "424601750970",
            "921601840678"
        ];
        request.add("username", "supercow");
        request.add("password", "12345678");
        request.add("winner_ticket", "621601750774");*/

        request.add("username", _username);
        request.add("password", _password);
        request.add("winner_ticket", _winnerTicket);
        request.addStringArray("tickets", currentTickets);
        request.addInt("winner_index", _winnerIndex);

        return sendChainlinkRequestTo(oracle, request, fee);
    }

    function fulfillWinnerData(bytes32 _requestId, int256 _winner)
        public
        recordChainlinkFulfillment(_requestId)
    {
        TICKET_MATCHES ticketMatches = TICKET_MATCHES.FOUR;

        int256 nMatches = _winner % 10;
        uint256 winnerIndex = uint256(_winner) / 10;

        if (nMatches == 5) {
            ticketMatches = TICKET_MATCHES.FIVE;
            fiveMatchesGroup++;
        } else if (nMatches == 6) {
            ticketMatches = TICKET_MATCHES.SIX;
            sixMatchesGroup++;
        } else {
            fourMatchesGroup++;
        }

        currentWinners.push(
            Winner(
                currentPlayers[winnerIndex].playerAddress,
                currentPlayers[winnerIndex].ticketNumber,
                block.timestamp,
                ticketMatches
            )
        );

        allWinners.push(
            Winner(
                currentPlayers[winnerIndex].playerAddress,
                currentPlayers[winnerIndex].ticketNumber,
                block.timestamp,
                ticketMatches
            )
        );

        emit WinnerFound(
            currentPlayers[winnerIndex].playerAddress,
            uint256(nMatches)
        );
    }

    function getWinnersData(
        string memory _winnerTicket,
        string memory _username,
        string memory _password
    ) public onlyOwner {
        if (lastNWinners > 0) {
            for (int256 i = 0; i < int256(lastNWinners); i++) {
                requestWinnerData(i, _winnerTicket, _username, _password);
            }
        }
    }

    function sendPrizesToWinners() public onlyOwner {
        require(lotteryState == LOTTERY_STATE.CALCULATING_WINNERS);

        if (currentWinners.length > 0) {
            address payable winnerAddress;
            TICKET_MATCHES ticketMatches;
            uint256 thirdPrizePart = 0;
            uint256 secondPrizePart = 0;
            uint256 firstPrizePart = 0;

            if (fourMatchesGroup > 0) {
                thirdPrizePart = thirdPrize / fourMatchesGroup;
                thirdPrize = 0;
            }

            if (fiveMatchesGroup > 0) {
                secondPrizePart = secondPrize / fiveMatchesGroup;
                secondPrize = 0;
            }

            if (sixMatchesGroup > 0) {
                firstPrizePart = secondPrize / fiveMatchesGroup;
                firstPrize = 0;
            }

            for (uint256 i = 0; i < currentWinners.length; i++) {
                ticketMatches = currentWinners[i].nMatches;
                winnerAddress = currentWinners[i].playerAddress;
                if (ticketMatches == TICKET_MATCHES.FOUR) {
                    winnerAddress.transfer(thirdPrizePart);
                    emit PrizeSent(winnerAddress, 4, thirdPrizePart);
                } else if (ticketMatches == TICKET_MATCHES.FIVE) {
                    winnerAddress.transfer(secondPrizePart);
                    emit PrizeSent(winnerAddress, 5, secondPrizePart);
                } else if (ticketMatches == TICKET_MATCHES.SIX) {
                    winnerAddress.transfer(firstPrizePart);
                    emit PrizeSent(winnerAddress, 6, firstPrizePart);
                }
            }
        }
    }

    function resetLists() internal {
        delete currentPlayers;
        delete currentTickets;
        delete currentWinners;
    }

    function recalculatePrizes() public {
        //TODO: Change from public to internal after tests.
        totalPrizes = firstPrize + secondPrize + thirdPrize;
        uint256 income = address(this).balance - totalPrizes;

        firstPrize += (income * FIRST_PRIZE_PERCENT) / 100;
        secondPrize += (income * SECOND_PRIZE_PERCENT) / 100;
        thirdPrize += (income * THIRD_PRIZE_PERCENT) / 100;
        earnings += (income * EARNINGS_PRIZE_PERCENT) / 100;
    }

    function withdrawLink(uint256 amount) public onlyOwner {
        require(linkToken.transfer(msg.sender, amount), "Transfer failed.");
    }

    function withdrawEarnings(uint256 amount) public onlyOwner {
        require(amount <= earnings, "Amount exceeded earnings");
        earnings -= amount;
        payable(msg.sender).transfer(amount);
    }

    function getTotalPrizes() public view returns (uint256) {
        return firstPrize + secondPrize + thirdPrize;
    }

    function withdrawAll() public onlyOwner {
        firstPrize = 0;
        secondPrize = 0;
        thirdPrize = 0;
        payable(msg.sender).transfer(address(this).balance);
    }
}
