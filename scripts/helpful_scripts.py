from brownie import accounts, LinkToken


def get_account(index=None, id=None):
    if index:
        return accounts[index]
    if id:
        return accounts.load(id)
    return accounts[0]


def deploy_mocks(account=None):
    if not account:
        account = get_account()
    else:
        account = account

    # Deploy LINK token
    link_token = LinkToken.deploy({"from": account})
    return link_token


def fund_with_link(
    contract_address, account=None, amount=10 ** 18, link_token=None
):  # 1 Link

    account = account if account else get_account()

    txn = link_token.transfer(contract_address, amount, {"from": account})
    txn.wait(1)
    print("Fund contract!!!")

    return txn
