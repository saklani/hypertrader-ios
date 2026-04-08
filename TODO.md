# Unsupported Order Features

Features supported by the Hyperliquid API but not yet implemented in hypertrader.

## Order Placement
- **`expiresAfter`** — Order expiry timestamp (ms). Causes orders to be rejected after that time. Requires appending `0x00 + timestamp(u64 BE)` to the hash input before signing.
- **`vaultAddress`** — Trading from a vault. Currently hardcoded to `null`. Requires appending `0x01 + address(20 bytes)` instead of `0x00` to the hash input.
- **`cloid`** — Client order ID for tracking. Field exists on `HLOrderWire` but always set to `nil`.
- **Trigger orders (TP/SL)** — `HLTriggerWire` model exists but no UI or VM logic to create them.
- **`grouping: "normalTpsl"` / `"positionTpsl"`** — Linking main orders with TP/SL. Always `"na"`.
- **Batch orders** — Placing multiple orders in a single action. Always 1 order per action.
- **`Alo` time-in-force** — Add Liquidity Only (maker-only orders). Model supports it but no UI option.

## Order Management
- **Modify order** — Updating price/size of a resting order without cancelling and replacing.
- **Cancel by cloid** — Cancelling by client order ID instead of server order ID.
- **Cancel all** — Bulk cancel all open orders.

## Position Management
- **Leverage adjustment** — Changing leverage for a position.
- **Margin mode** — Switching between cross and isolated margin.
- **Transfer margin** — Moving margin between positions.
