from brownie import accounts, config, network
from web3 import Web3

LOCAL_BLOCKCHAIN_ENVIRONMENT = ["development","ganache-local","mainnet-fork"]

def get_account(number:int):
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        return accounts[number-1]
    else:
        return accounts.add(config["wallets"]["account"+str(number)])
