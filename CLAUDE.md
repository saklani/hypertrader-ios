# hypertrader

iOS SwiftUI app for trading perps and spot on Hyperliquid. Currently wired to **mainnet** (`api.hyperliquid.xyz`).

## Architecture

Two-key trading model:

1. **Master wallet** — user's real wallet (Rainbow / MetaMask / Coinbase / Trust / Uniswap / Zerion / OKX), connected via a custom WalletConnect v2 client. Used only to (a) prove address ownership and (b) sign a one-time `approveAgent` typed-data message.
2. **Agent wallet** — a local secp256k1 keypair generated on device, stored in Keychain (`com.hypertrader.agent-wallet`). All L1 actions (orders, cancels, closes) are signed locally with this key. No wallet prompts on the trade path.

`AuthViewModel.setupAgentWallet()` runs the approval flow: generate/load agent key → build `approveAgent` EIP-712 → sign via WalletConnect → POST to Hyperliquid exchange.

### Signing pipeline (`HyperliquidSigner.sign`)

L1 action → `MessagePackEncoder` → append `nonce(u64 BE)` + `0x00` (vault byte) → Keccak256 → phantom-agent EIP-712 wrap → `EthereumSigner.sign` (libsecp256k1, recoverable). Runs on a detached Task. Nonce = `Date().timeIntervalSince1970 * 1000`.

### Custom crypto stack (no WalletConnect SDK)

- `WalletConnectClient.swift` — minimal WalletConnect v2 dApp client (`WalletConnectClient` actor): pairing, session proposal, `eth_signTypedData_v4`. Uses only `CryptoKit` (X25519, ChaCha20-Poly1305, HKDF, Ed25519) and `URLSessionWebSocketTask`. Ed25519 relay identity key persisted in `UserDefaults` under `com.hypertrader.wc.relay.ed25519`. JSON-RPC ids are generated as `ms*1000 + rand(0..999)` to stay within JS `Number.MAX_SAFE_INTEGER` — larger ids get BigInt-serialized by wallets and silently rejected. Connection flow is split into `createPairingURI` → `prepareSession` (connect + subscribe + publish proposal) → `awaitSession`; always publish before showing the URI/QR so the wallet has a message waiting.
- `MessagePack.swift` — custom minimal MessagePack encoder for `Codable` (strings, ints, bools, nil, maps, arrays). Required because HL order hashing is msgpack-based.
- `Keccak256.swift` — custom Keccak-256 (no external dep).
- `EthereumSigner.swift` — secp256k1 ECDSA via `libsecp256k1` SPM package.

WC project ID is hardcoded in `WalletConnectManager.initialize()`.

## Services (all in `hypertrader/Services/`)

- `HyperliquidInfoService` — read-only REST (`/info`). `meta`, `allMids`, `clearinghouseState`, `openOrders`, `userFills`, `metaAndAssetCtxs` (+ builder dex variant), `spotMetaAndAssetCtxs`, `candleSnapshot`, `perpDexs`, `perpCategories`.
- `HyperliquidExchangeService` — write REST (`/exchange`). `place`, `cancel`, `close`, `approveAgent`. **All orders carry a hardcoded builder fee**: `0x73bb3A6A37e95BA396ffabA868F912485Bed4B03`, 3 bp (`f: 30` tenths of a bp).
- `HyperliquidWebSocketService` — singleton, subscribes to `allMids` always + one `candle` channel at a time. Auto-reconnects and re-subscribes. Exposes `mids: [String: String]` and an `onCandleUpdate` callback.
- `WalletConnectManager` — `@Observable @MainActor` shim over `WalletConnectClient`. Exposes `connect(wallet:)`, `generateURI()` / `waitForSession()` (manual copy-paste fallback), `signTypedData`, `disconnect`.

## UI structure

`hypertraderApp` → `ContentView` → `MainTabView` with three tabs: **Markets**, **Positions**, **Settings**. `MainTabView.task` kicks off `HyperliquidWebSocketService.shared.connect()`. (`PortfolioView` still exists on disk but is not wired into the tab bar.)

UI code lives under `hypertrader/Features/<feature>/`, with each feature folder colocating its views and its view models. Current features: `Auth`, `Markets`, `Positions`, `Portfolio` (dormant), `Settings`. `MainTabView.swift` lives at `hypertrader/Features/` top level since it's the composition root for the feature set, not owned by any single feature. There is no separate `Views/` or `ViewModels/` folder.

`LoginView` (in `Features/Auth/`) is presented as a sheet from two places: `SettingsView`'s "Connect Wallet" button, and `ConnectWalletView` (the tappable "Connect a wallet to trade" placeholder that `MarketView` shows in place of `OrderFormView` whenever `market.isWalletReady == false`). Both callers own their own local `AuthViewModel` and pass it into `LoginView` via `@Bindable` so approval state stays in sync — `isAgentApproved` is per-instance on `AuthViewModel`. The *shared* "is trading unlocked" state lives on `WalletConnectManager.shared.isAgentReady` (observable), which `AuthViewModel.setupAgentWallet()` flips after successful approval and `MarketViewModel.isWalletReady` reads. That's what lets any view in the app react to approval without the originating `AuthViewModel` instance being visible to them.

ViewModels are all `@Observable @MainActor final class` and mostly `@State`-owned by the individual view that needs them — child views like `OrderFormView`, `ActivePositionView`, `TradeHistoryView`, `CandlestickChartView`, and `ConnectWalletView` each own their own VM internally. `MarketView` owns only `MarketViewModel` (asset selection + WS passthrough) and composes the self-contained children, coordinating reloads via a `reloadCounter: Int` that children watch through `.task(id:)`. No DI container. Singletons for services.

- `MarketViewModel` — asset list + selection, persists `selectedAssetName` in UserDefaults. Owned by `MarketView`.
- `OrderViewModel` — order form state + placement. Market orders use WS `mids` and apply `slippage` (default 1%) to synthesize a limit price with IOC tif. Limit orders use GTC. Owned internally by `OrderFormView`.
- `PositionsViewModel` — loads `clearinghouseState` for the all-positions tab. Owned by `PositionsView`.
- `AssetPositionViewModel` — per-asset active position used inline in Markets, supports close-position. Owned internally by `ActivePositionView`.
- `ChartViewModel` — candle data + interval. Owned internally by `CandlestickChartView`.
- `TradeHistoryViewModel` — per-asset fills list. Owned internally by `TradeHistoryView`.
- `AuthViewModel` — wallet connect + agent approval flow. Instantiated locally by `ConnectWalletView`, `SettingsView`, and `LoginView`'s callers.

Shared styles in `hypertrader/Styles/` (`ButtonStyles`, `CardStyles`, `ChipStyles`, `DialogStyles`, `ListItemStyles`, `TextFieldStyles`). Minimal/functional aesthetic is intentional for v1.

## Config

`hypertrader/Config/HyperliquidConfig.swift` is the single switch for network. Flipping the URLs and `signatureChainId` / `userSignedChainId` / `chainName` moves the whole app between mainnet and testnet. Currently mainnet:

- `infoURL` / `exchangeURL` / `wsURL` → `*.hyperliquid.xyz`
- `signatureChainId = 0xa4b1`, `userSignedChainId = 42161`, `chainName = "Mainnet"`
- `phantomAgentSource = "a"` (mainnet phantom agent source; testnet uses `"b"`)

## SPM dependencies

Resolved via the Xcode project (not Package.swift):

- `libsecp256k1` (GigaBitcoin/secp256k1.swift) — ECDSA
- No WalletConnect, no CryptoSwift, no MessagePacker — all replaced by in-tree implementations.

## Tests

`hypertraderTests/` has `HyperliquidServiceTests` and `HyperliquidExchangeServiceTests`. UI tests in `hypertraderUITests/`.

Two root-level Python scripts (`debug_hl_api.py`, `debug_hl_exchange.py`) are local debug harnesses against the HL API — not part of the app build.

## Unsupported features

See `TODO.md` for the list of HL API features not yet wired up: `expiresAfter`, `vaultAddress`, `cloid`, trigger orders (TP/SL), `normalTpsl` / `positionTpsl` grouping, batch orders, `Alo` tif, modify order, cancel-by-cloid, cancel-all, leverage/margin-mode adjustments.

## Conventions

- Mainnet. Don't flip `HyperliquidConfig` without being asked.
- Trade signing must stay fully local — nothing on the hot path should route through WalletConnect.
- New files under `hypertrader/` are picked up automatically via `PBXFileSystemSynchronizedRootGroup` in the Xcode project — no manual `project.pbxproj` edit is needed. Same for `hypertraderTests/` and `hypertraderUITests/`.
- Prices and sizes are passed around as strings (HL API convention); use `Utils/PriceFormatting.swift` helpers rather than ad-hoc `String(format:)`.
- Hyperliquid order-wire types (`HLOrderWire`, `HLOrderAction`, etc.) are `nonisolated Sendable` because signing runs on a detached Task. Preserve those annotations.
- The project uses `@MainActor` as default isolation — file-scope free functions that need to be callable from actor-isolated or background contexts (e.g., `wcLog` in `WalletConnectClient.swift`) must be explicitly marked `nonisolated`.
