from brownie import EthLottery, network
from scripts.helpful_scripts import get_account


def deploy_eth_lottery():
    account = get_account()
    print("Deploying ETH Lottery...")
    eth_lottery = EthLottery.deploy({"from": account})
    print(
        f"Lottery deployed in {network.show_active()} with address {eth_lottery.address}"
    )
    return eth_lottery


def main():
    deploy_eth_lottery()
