# SSH Migration Design

Replace plaintext HTTP + bearer token auth with SSH tunneling via Citadel.
Agent binds to localhost only, token auth removed. SSH handles encryption and authentication.

## Current Architecture

```
Mac App ──HTTP (plaintext)──→ Agent (0.0.0.0:7654, bearer token)
```

- Client: `AgentClient` uses `URLSession` for HTTP/SSE to `http://{host}:{port}/`
- Agent: Go HTTP server at `/Users/neur0map/prowl/deskmon-agent/`, binds `0.0.0.0:7654`
- Auth: Bearer token in `Authorization` header, validated by `authMiddleware` in `internal/api/server.go`
- Credentials stored: `ServerInfo` holds `host`, `port`, `token` in memory

## New Architecture

```
Mac App ──SSH (Citadel)──tunnel──→ Agent (127.0.0.1:7654, no auth)
```

- Client: Citadel SSH connection, `directTCPIP` channel forwarding to `localhost:7654`
- Agent: Same HTTP server, binds `127.0.0.1:7654`, auth middleware removed
- Auth: SSH key (auto-generated ed25519) with password fallback, stored in macOS Keychain
- All existing HTTP/SSE code flows unchanged through the tunnel

## Onboarding Flow

First-time setup (user enters 3 fields: host, username, password):

1. User taps "Add Server", enters hostname, SSH username, SSH password, taps "Connect"
2. App connects via Citadel password auth
3. On success: open `directTCPIP` channel to `127.0.0.1:7654`
4. Fetch `GET /stats` through tunnel to verify agent is running
5. If agent responds: save server, start SSE stream, show dashboard
6. Background (silent): generate ed25519 key pair, store private key in Keychain, install public key on server via SSH exec (`~/.ssh/authorized_keys`)
7. Store password in Keychain as fallback

Subsequent connections (zero user interaction):

1. App launches, loads saved servers
2. Try key auth first (private key from Keychain)
3. If key fails, fall back to password from Keychain
4. If both fail, prompt "Re-enter password"
5. On SSH connected: open tunnel, fetch snapshot, start SSE

## Connection Phases

```swift
enum ConnectionPhase {
    case disconnected     // No SSH session
    case sshConnecting    // SSH handshake in progress
    case sshConnected     // SSH up, opening tunnel
    case tunnelOpen       // Tunnel open, fetching agent snapshot
    case live             // SSE streaming through tunnel
}
```

## Reconnection Strategy

SSH drops (network change, server reboot, sleep/wake):
- Detect via Citadel channel close / NIO error
- Set phase to `.disconnected`
- Retry with exponential backoff: 2s, 4s, 8s, 16s, 30s max
- Try key auth first, then password fallback
- On success: reopen tunnel, refetch snapshot, restart SSE

Agent unreachable through tunnel (agent crashed):
- SSH stays connected
- HTTP request to tunnel fails
- Retry agent connection with backoff
- UI shows "Agent offline" while SSH stays up

Mac sleep/wake:
- SSH will drop (TCP timeout)
- On wake: immediate reconnect attempt, no backoff for first try

## Error States

| Condition | Sidebar status | Action |
|-----------|---------------|--------|
| SSH connecting | Amber dot, "Connecting..." | Auto |
| SSH auth failed | Red dot, "Auth failed" | Prompt re-enter password |
| SSH connected, agent down | Amber dot, "Agent offline" | Auto-retry |
| Fully live | Green dot, "Connected" | None |
| Network lost | Amber dot, "Reconnecting..." | Auto-retry |

## App Lock PIN

Optional 4-digit PIN to lock the app after onboarding.

Setup: after first server connected, app prompts "Set a PIN to lock deskmon?" with a skip option. Can also be configured later.

```swift
enum LockScope: String, Codable {
    case off          // No PIN required
    case menuBarOnly  // Only the popover
    case windowOnly   // Only the main window
    case both         // Both surfaces
}
```

Lock behavior:
- Surfaces re-lock on dismiss/close, sleep/wake, and after 5 min idle
- PIN stored as SHA-256 + salt hash in Keychain
- 5 failed attempts triggers 30 second cooldown
- Forgot PIN: delete the server and re-add

## Client Changes (deskmon)

### New Dependency

```
Citadel (https://github.com/orlandos-nl/Citadel) >= 0.7.0
```

### New Files

| File | Purpose |
|------|---------|
| `Services/SSHManager.swift` | Per-server Citadel SSH connection, tunnel lifecycle, key/password auth, reconnect loop |
| `Services/KeychainStore.swift` | Store/retrieve SSH passwords, private keys, hashed PIN via Security framework |
| `Services/SSHKeyGenerator.swift` | Generate ed25519 key pair, install public key on server via SSH exec channel |
| `Services/AppLockManager.swift` | Observable: lock scope, lock state per surface, idle timer, PIN verify/set |
| `Views/Components/AppLockView.swift` | PIN entry overlay: 4 circles, keypad input, cooldown on failures |
| `Views/Components/PINSetupView.swift` | Post-onboarding PIN prompt and settings PIN change |

### Modified Files

| File | Changes |
|------|---------|
| `Models/ServerInfo.swift` | Replace `port` + `token` with `sshPort` (default 22), `agentPort` (default 7654), `username`. Add `hasKeyInstalled: Bool` |
| `Services/AgentClient.swift` | Remove `verifyConnection`, `checkHealth`, token headers. Accept tunnel base URL from SSHManager. Keep all HTTP/SSE code |
| `Services/ServerManager.swift` | Connect flow: SSHManager.connect then open tunnel then AgentClient.fetchStats then start SSE. Wire up reconnect. Drop token references |
| `Views/AddServerSheet.swift` | Fields: name, host, username, password. Remove port/token. "Connect" triggers SSH + agent verify |
| `Views/EditServerSheet.swift` | Same field changes, option to update password |
| `Views/DashboardView.swift` | Wrap content in AppLockView overlay when locked |
| `Views/MainDashboardView.swift` | Wrap content in AppLockView overlay when locked. Add lock scope toggle to settings area |

## Agent Changes (deskmon-agent)

### Modified Files

| File | Changes |
|------|---------|
| `internal/config/config.go` | Change `DefaultBind` from `"0.0.0.0"` to `"127.0.0.1"`. Remove `AuthToken` field. Remove `ServicesConfig`/`PiHoleConfig` |
| `internal/api/server.go` | Remove `authMiddleware` function. Remove `s.authMiddleware()` wrapper from all route handlers. Remove service-related routes (`/stats/services`, `/services/{pluginId}/*`) |
| `internal/api/handlers.go` | Remove service-related handler functions if present |

The agent keeps its HTTP server, SSE streaming, rate limiting, and security headers. Only auth and bind address change.

## Implementation Order

### Phase 1: Foundation (no UI changes)

1. Add Citadel SPM dependency to Xcode project
2. Create `KeychainStore` — password, private key, and PIN hash storage via `SecItemAdd`/`SecItemCopyMatching`/`SecItemDelete`
3. Create `SSHManager` — Citadel SSH connect, `directTCPIP` tunnel channel, reconnect with backoff
4. Create `SSHKeyGenerator` — ed25519 key generation, public key install via SSH exec channel

### Phase 2: Wire SSH into connection flow

5. Update `ServerInfo` model — `username`, `sshPort`, `agentPort`, drop `token`
6. Update `AgentClient` — remove token headers, accept tunnel base URL, keep HTTP/SSE unchanged
7. Update `ServerManager` — SSH connect, tunnel open, SSE start orchestration
8. Migrate persisted server data to new model shape

### Phase 3: Onboarding UI

9. Update `AddServerSheet` — host, username, password fields
10. Update `EditServerSheet` — same field changes
11. Update sidebar footer — connection states match new `ConnectionPhase` values

### Phase 4: App Lock

12. Create `AppLockManager` — lock scope, state, idle timer, PIN verify/set
13. Create `AppLockView` — PIN entry overlay
14. Create `PINSetupView` — post-onboarding prompt and settings
15. Wire lock overlays into `DashboardView` and `MainDashboardView`

### Phase 5: Agent changes

16. Update `config.go` — bind `127.0.0.1`, remove `AuthToken`, remove services config
17. Update `server.go` — remove `authMiddleware`, strip service routes
18. Clean up any orphaned service handler code

### Phase 6: Polish

19. Auto-reconnect on wake via `NSWorkspace.didWakeNotification`
20. Error state refinement — auth failed prompts re-enter password
21. End-to-end test with real server
