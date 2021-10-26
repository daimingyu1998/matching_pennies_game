from brownie import MatchingPennies, network, config
from scripts.helper import (
    get_account,
    LOCAL_BLOCKCHAIN_ENVIRONMENT,
)
from web3 import Web3
import threading
import secrets
from sha3 import keccak_256
import time


def deploy_matching_pennies():
    account1 = get_account(1)
    return MatchingPennies.deploy(
        {"from": account1},
        publish_source=config["networks"][network.show_active()].get("verify"),
    )


def play_matching_pennies(matching_pennies):
    account1 = get_account(1)
    account2 = get_account(2)
    print(account1.balance())
    print(account2.balance())
    t1 = threading.Thread(target=play, args=(matching_pennies, account1, 1, True))
    t2 = threading.Thread(target=play, args=(matching_pennies, account2, 2, False))
    t1.start()
    t2.start()
    time.sleep(20)
    # t3 = threading.Thread(target=play,args=(matching_pennies,account1,1,True))
    # t4 = threading.Thread(target=play,args=(matching_pennies,account2,2,False))
    # t3.start()
    # t4.start()


def play(matching_pennies, account, choice, sleep):
    assert choice == 1 or choice == 2
    matching_pennies.registor(
        {"from": account, "value": 10 ** 18, "gas_limit": 10 ** 5}
    )
    print("Matching Complete: ",account.address)
    while matching_pennies.getGameStatus() == "Matching":
        time.sleep(1)
    address_bytes = bytes.fromhex(account.address[2:])
    choice_bytes = bytes([choice])
    random_bytes = generate_random_bytes32()
    hash = keccak_256()
    hash.update(address_bytes + choice_bytes + random_bytes)
    matching_pennies.commit(hash.hexdigest(), {"from": account, "gas_limit": 10 ** 5})
    print("Playing Complete: ",account.address)
    while matching_pennies.getGameStatus() == "Committing":
        time.sleep(1)
    matching_pennies.reveal(
        choice, random_bytes, {"from": account, "gas_limit": 10 ** 6}
    )
    print("Revealing Complete: ",account.address)
    while matching_pennies.getGameStatus() == "Revealing":
        time.sleep(1)


def generate_random_bytes32():
    return secrets.token_bytes(32)


def main():
    matching_pennies = deploy_matching_pennies()
    play_matching_pennies(matching_pennies)
