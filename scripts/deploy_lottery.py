from brownie import EthLottery, network, config
from brownie.convert import to_bytes, to_address
from scripts.helpful_scripts import deploy_mocks, get_account, fund_with_link
import os


def deploy_eth_lottery(
    oracle,
    number_of_winners_job_id,
    get_winners_job_id,
    ticket_value,
):
    account = get_account(id="kovan-account")
    print("Deploying ETH Lottery...")
    eth_lottery = EthLottery.deploy(
        oracle,
        number_of_winners_job_id,
        get_winners_job_id,
        ticket_value,
        config["networks"][network.show_active()]["link_token_address"],
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )
    print(
        f"Lottery deployed in {network.show_active()} with address {eth_lottery.address}"
    )
    return eth_lottery


def main():
    deploy_eth_lottery(
        os.getenv("ORACLE_ADDRESS"),
        bytes(os.getenv("NUMBER_OF_WINNERS_JOB_ID"), encoding="utf-8"),
        bytes(os.getenv("GET_WINNERS_JOB_ID"), encoding="utf-8"),
        10 ** 15,
    )
