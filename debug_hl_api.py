#!/usr/bin/env python3
"""Debug script to test Hyperliquid testnet WebSocket + REST candle API."""

import asyncio
import json
import time
import urllib.request

# --- REST: candleSnapshot ---
def test_rest_candles():
    print("=" * 60)
    print("TEST 1: REST candleSnapshot")
    print("=" * 60)

    url = "https://api.hyperliquid-testnet.xyz/info"
    now_ms = int(time.time() * 1000)
    start_ms = now_ms - (3600_000 * 200)  # last 200 hours

    body = json.dumps({
        "type": "candleSnapshot",
        "req": {
            "coin": "BTC",
            "interval": "1h",
            "startTime": start_ms,
            "endTime": now_ms
        }
    }).encode()

    print(f"POST {url}")
    print(f"Body: {json.loads(body)}")
    print()

    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read())
            print(f"Status: {resp.status}")
            print(f"Candles returned: {len(data)}")
            if data:
                print(f"\nFirst candle:")
                print(json.dumps(data[0], indent=2))
                print(f"\nField types:")
                for k, v in data[0].items():
                    print(f"  {k}: {type(v).__name__} = {v}")
            else:
                print("Empty response!")
    except Exception as e:
        print(f"ERROR: {e}")

# --- REST: allMids ---
def test_rest_mids():
    print("\n" + "=" * 60)
    print("TEST 2: REST allMids")
    print("=" * 60)

    url = "https://api.hyperliquid-testnet.xyz/info"
    body = json.dumps({"type": "allMids"}).encode()

    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read())
            print(f"Status: {resp.status}")
            # Just show first 5 entries
            items = list(data.items())[:5]
            for k, v in items:
                print(f"  {k}: {v} ({type(v).__name__})")
            print(f"  ... ({len(data)} total)")
    except Exception as e:
        print(f"ERROR: {e}")

# --- WebSocket ---
async def test_websocket():
    print("\n" + "=" * 60)
    print("TEST 3: WebSocket connection")
    print("=" * 60)

    import websockets

    url = "wss://api.hyperliquid-testnet.xyz/ws"
    print(f"Connecting to {url}...")

    try:
        async with websockets.connect(url) as ws:
            print("Connected!")

            # Subscribe to allMids
            sub = json.dumps({"method": "subscribe", "subscription": {"type": "allMids"}})
            print(f"\nSending: {sub}")
            await ws.send(sub)

            # Read first 3 messages
            for i in range(3):
                msg = await asyncio.wait_for(ws.recv(), timeout=5)
                data = json.loads(msg)
                channel = data.get("channel", "?")
                print(f"\nMessage {i+1} (channel={channel}):")
                if channel == "allMids":
                    mids = data.get("data", {}).get("mids", {})
                    items = list(mids.items())[:3]
                    for k, v in items:
                        print(f"  {k}: {v}")
                    print(f"  ... ({len(mids)} total)")
                else:
                    print(json.dumps(data, indent=2)[:500])

            # Subscribe to candle
            sub2 = json.dumps({"method": "subscribe", "subscription": {"type": "candle", "coin": "BTC", "interval": "1m"}})
            print(f"\nSending: {sub2}")
            await ws.send(sub2)

            # Read next 3 messages
            for i in range(3):
                msg = await asyncio.wait_for(ws.recv(), timeout=10)
                data = json.loads(msg)
                channel = data.get("channel", "?")
                print(f"\nMessage {i+4} (channel={channel}):")
                if channel == "candle":
                    print(json.dumps(data.get("data", {}), indent=2)[:500])
                else:
                    truncated = json.dumps(data, indent=2)[:300]
                    print(truncated)

    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    test_rest_candles()
    test_rest_mids()
    asyncio.run(test_websocket())
