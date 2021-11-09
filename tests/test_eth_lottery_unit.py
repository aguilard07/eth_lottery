from brownie import exceptions
from scripts.deploy_lottery import deploy_eth_lottery
from scripts.helpful_scripts import get_account
from web3 import Web3

import pytest


def test_can_start_and_end_lottery():
    account = get_account()
    eth_lottery = deploy_eth_lottery()
    eth_lottery.startLottery({"from": account})
    assert eth_lottery.lotteryState() == 0
    eth_lottery.endLottery({"from": account})
    assert eth_lottery.lotteryState() == 1


def test_only_owner_can_start_lottery():
    account = get_account(index=1)  # The owner is the index 0.
    eth_lottery = deploy_eth_lottery()
    with pytest.raises(exceptions.VirtualMachineError):
        eth_lottery.startLottery({"from": account})


def test_only_owner_can_end_lottery():
    owner_account = get_account()
    other_account = get_account(index=1)
    eth_lottery = deploy_eth_lottery()
    eth_lottery.startLottery({"from": owner_account})
    with pytest.raises(exceptions.VirtualMachineError):
        eth_lottery.endLottery({"from": other_account})


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


def test_cannot_enter_lottery_until_is_open():
    account = get_account()
    eth_lottery = deploy_eth_lottery()
    ticket = "010203251731"
    with pytest.raises(exceptions.VirtualMachineError):
        eth_lottery.enterLottery(
            ticket, {"from": account, "value": eth_lottery.ticketValue()}
        )


def test_can_enter_lottery():
    account = get_account()
    eth_lottery = deploy_eth_lottery()
    ticket = "010203251731"
    eth_lottery.startLottery({"from": account})
    eth_lottery.enterLottery(
        ticket, {"from": account, "value": eth_lottery.ticketValue()}
    )
    assert eth_lottery.players(0)[0] == account


def test_fund_lottery():
    account = get_account()
    eth_lottery = deploy_eth_lottery()
    eth_lottery.fundLottery({"from": account, "value": Web3.toWei(10, "ether")})
    assert eth_lottery.balance() == Web3.toWei(10, "ether")
    assert eth_lottery.firstPrize() == Web3.toWei(10 * 0.60, "ether")
    assert eth_lottery.secondPrize() == Web3.toWei(10 * 0.25, "ether")
    assert eth_lottery.thirdPrize() == Web3.toWei(10 * 0.15, "ether")
