#!/usr/bin/env python3
"""
Reference test for HyperliquidExchangeService signing chain.
Uses the official Python SDK to generate expected intermediate values
that our Swift implementation must match.
"""

import json
import time
import msgpack
from eth_account import Account
from hyperliquid.utils.signing import sign_l1_action
import hashlib

# ============================================================
# Known test private key (DO NOT use with real funds)
# This is Hardhat's account #0
# ============================================================
PRIVATE_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
wallet = Account.from_key(PRIVATE_KEY)
print(f"Wallet address: {wallet.address}")

# ============================================================
# TEST 1: Build an order and capture intermediate values
# ============================================================
print("\n" + "=" * 60)
print("TEST 1: Order signing intermediate values")
print("=" * 60)

# Order parameters
asset_index = 3  # BTC on testnet
is_buy = True
limit_px = "95000"
sz = "0.01"
reduce_only = False
order_type = {"limit": {"tif": "Gtc"}}
cloid = None

# Build the order wire format (same as our HLOrderWire)
order_wire = {
    "a": asset_index,
    "b": is_buy,
    "p": limit_px,
    "s": sz,
    "r": reduce_only,
    "t": order_type,
    "c": cloid,
}

# Build the action (same as our HLOrderAction)
# Note: builder is NOT included in the signed action for the Python SDK's default behavior
action = {
    "type": "order",
    "orders": [order_wire],
    "grouping": "na",
}

print(f"\nOrder wire: {json.dumps(order_wire)}")
print(f"Action: {json.dumps(action)}")

# Step 1: MessagePack encode
msgpack_bytes = msgpack.packb(action)
print(f"\nMessagePack bytes ({len(msgpack_bytes)} bytes): {msgpack_bytes.hex()}")

# Step 2: Build hash input = msgpack + nonce(u64 BE) + vault(0x00)
# Use a fixed nonce for reproducibility
fixed_nonce = 1700000000000
nonce_bytes = fixed_nonce.to_bytes(8, byteorder='big')
vault_byte = b'\x00'
hash_input = msgpack_bytes + nonce_bytes + vault_byte
print(f"Nonce: {fixed_nonce}")
print(f"Hash input ({len(hash_input)} bytes): {hash_input.hex()}")

# Step 3: Keccak256 hash
from eth_account._utils.signing import to_bytes
from Crypto.Hash import keccak as keccak_mod

def keccak256(data: bytes) -> bytes:
    k = keccak_mod.new(digest_bits=256)
    k.update(data)
    return k.digest()

action_hash = keccak256(hash_input)
print(f"Action hash (keccak256): 0x{action_hash.hex()}")

# Step 4: EIP-712 phantom agent typed data
# Source = "b" for testnet
phantom_agent = {
    "source": "b",
    "connectionId": "0x" + action_hash.hex(),
}
print(f"Phantom agent: {json.dumps(phantom_agent)}")

# Step 5: Use the SDK's sign_l1_action to get the full signature
# This does steps 1-6 internally
timestamp = fixed_nonce
signature = sign_l1_action(wallet, action, None, timestamp, False, is_mainnet=False)
print(f"\nFinal signature: {json.dumps(signature)}")

# ============================================================
# TEST 2: Order with builder fee
# ============================================================
print("\n" + "=" * 60)
print("TEST 2: Order with builder fee")
print("=" * 60)

action_with_builder = {
    "type": "order",
    "orders": [order_wire],
    "grouping": "na",
    "builder": {"b": "0x73bb3A6A37e95BA396ffabA868F912485Bed4B03", "f": 30},
}

msgpack_bytes_builder = msgpack.packb(action_with_builder)
print(f"Action with builder: {json.dumps(action_with_builder)}")
print(f"MessagePack bytes ({len(msgpack_bytes_builder)} bytes): {msgpack_bytes_builder.hex()}")

hash_input_builder = msgpack_bytes_builder + nonce_bytes + vault_byte
action_hash_builder = keccak256(hash_input_builder)
print(f"Action hash: 0x{action_hash_builder.hex()}")

# ============================================================
# TEST 3: Cancel action
# ============================================================
print("\n" + "=" * 60)
print("TEST 3: Cancel action")
print("=" * 60)

cancel_action = {
    "type": "cancel",
    "cancels": [{"a": 3, "o": 12345}],
}

cancel_msgpack = msgpack.packb(cancel_action)
print(f"Cancel action: {json.dumps(cancel_action)}")
print(f"MessagePack bytes ({len(cancel_msgpack)} bytes): {cancel_msgpack.hex()}")

cancel_hash_input = cancel_msgpack + nonce_bytes + vault_byte
cancel_action_hash = keccak256(cancel_hash_input)
print(f"Action hash: 0x{cancel_action_hash.hex()}")

cancel_sig = sign_l1_action(wallet, cancel_action, None, timestamp, False, is_mainnet=False)
print(f"Signature: {json.dumps(cancel_sig)}")

# ============================================================
# TEST 4: Actually POST an order to testnet
# ============================================================
print("\n" + "=" * 60)
print("TEST 4: POST order to testnet")
print("=" * 60)

import requests

# Place a limit buy very far below market (won't fill, just tests API acceptance)
test_order = {
    "a": 3,  # BTC
    "b": True,
    "p": "1000",  # $1000 — way below market, won't fill
    "s": "0.001",
    "r": False,
    "t": {"limit": {"tif": "Gtc"}},
    "c": None,
}

test_action = {
    "type": "order",
    "orders": [test_order],
    "grouping": "na",
}

now = int(time.time() * 1000)
test_sig = sign_l1_action(wallet, test_action, None, now, False, is_mainnet=False)

body = {
    "action": test_action,
    "nonce": now,
    "signature": test_sig,
    "vaultAddress": None,
}

print(f"Request body: {json.dumps(body, indent=2)}")

resp = requests.post("https://api.hyperliquid-testnet.xyz/exchange", json=body)
print(f"\nResponse status: {resp.status_code}")
print(f"Response body: {resp.text}")

# If successful, cancel it immediately
if resp.status_code == 200:
    result = resp.json()
    print(f"Parsed response: {json.dumps(result, indent=2)}")

    # Try to get the order ID from response
    if result.get("status") == "ok":
        statuses = result.get("response", {}).get("data", {}).get("statuses", [])
        for s in statuses:
            if "resting" in s:
                oid = s["resting"]["oid"]
                print(f"\nOrder placed! OID: {oid}")

                # Cancel it
                cancel = {"type": "cancel", "cancels": [{"a": 3, "o": oid}]}
                cancel_now = int(time.time() * 1000)
                cancel_sig = sign_l1_action(wallet, cancel, None, cancel_now, False, is_mainnet=False)
                cancel_body = {"action": cancel, "nonce": cancel_now, "signature": cancel_sig, "vaultAddress": None}
                cancel_resp = requests.post("https://api.hyperliquid-testnet.xyz/exchange", json=cancel_body)
                print(f"Cancel response: {cancel_resp.text}")

print("\n" + "=" * 60)
print("SUMMARY: Use these values as expected outputs in Swift tests")
print("=" * 60)
print(f"Private key: {PRIVATE_KEY}")
print(f"Address: {wallet.address}")
print(f"Fixed nonce: {fixed_nonce}")
print(f"Order msgpack hex: {msgpack_bytes.hex()}")
print(f"Order action hash: 0x{action_hash.hex()}")
print(f"Order with builder msgpack hex: {msgpack_bytes_builder.hex()}")
print(f"Order with builder action hash: 0x{action_hash_builder.hex()}")
print(f"Cancel msgpack hex: {cancel_msgpack.hex()}")
print(f"Cancel action hash: 0x{cancel_action_hash.hex()}")
