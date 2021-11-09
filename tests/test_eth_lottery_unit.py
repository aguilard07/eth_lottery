from brownie import EthLottery
from scripts.deploy_lottery import deploy_eth_lottery
from scripts.helpful_scripts import get_account


def test_ticket_validation():
    eth_lottery = deploy_eth_lottery()
    ticket1 = "as+5a14f68"
    ticket2 = "11111111111111111"
    ticket3 = "123-1235-54"
    ticket4 = "010203251731"
    # Assert
    assert eth_lottery.validateTicket(ticket1) == False
    assert eth_lottery.validateTicket(ticket2) == False
    assert eth_lottery.validateTicket(ticket3) == False
    assert eth_lottery.validateTicket(ticket4) == True
