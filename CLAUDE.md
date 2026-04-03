# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Build (debug)
swift build

# Build (release)
swift build -c release

# Run directly
swift run

# Open in Xcode (recommended for GUI development)
open Package.swift
```

VSCode launch configurations are in [.vscode/launch.json](.vscode/launch.json) — use the **Swift** extension with "Debug LGNetCastRemote".

There are no automated tests in this project.

## Architecture

This is a **macOS-only menubar app** (macOS 13+, SPM, SwiftUI) that controls legacy LG NetCast TVs (pre-2014, HDCP API on port 8080). The original Python/Tkinter/rumps implementation is preserved in the root directory for reference.

### Data flow

```
MenuBarView / RemoteView
       ↓  calls async methods
  TVController  (@MainActor ObservableObject)
       ↓  URLSession HTTP POST with XML bodies
  LG TV  (http://<ip>:8080/hdcp/api)
```

### TV protocol

All communication is HTTP POST with UTF-8 XML bodies to `http://<ip>:8080/hdcp/api`:

- **PIN display** → POST `/hdcp/api/auth` with `<auth><type>AuthKeyReq</type></auth>`
- **Authenticate** → POST `/hdcp/api/auth` with `<auth><type>AuthReq</type><value>PIN</value></auth>` → parse `<session>` from response
- **Key press** → POST `/dtv_wifirc` or `/command` (tries both) with `<command><session>…</session><type>HandleKeyInput</type><value>KEY_CODE</value></command>`

Session tokens expire; `TVController.sendKey()` auto-reconnects when it detects a stale session.

### Device discovery

`SSDPDiscovery` (actor) runs three strategies in order, stopping when any yields results:
1. **SSDP M-SEARCH** — UDP multicast to `239.255.255.250:1900`
2. **B-SEARCH** — UDP broadcast to `255.255.255.255:1990`
3. **Port scan** — concurrent TCP connects to `:8080` across the local `/24` subnet

All three use raw BSD sockets via Darwin (no Network.framework). The app sandbox must be **disabled** for raw sockets and multicast to work.

### Key files

| File | Role |
|---|---|
| `LGNetCastApp.swift` | `@main` entry; `MenuBarExtra` + `Window("remote")` scenes; `AppDelegate` sets `.accessory` activation policy |
| `TVController.swift` | All network I/O; `@Published` state drives both UI surfaces |
| `KeyMap.swift` | `LGKey` enum — every case has a `.code: Int` for the HDCP key-input value |
| `TVState.swift` | `ConnectionState` enum (disconnected / connecting / connected(session:) / error), `TVDevice`, `TVState` (Codable) |
| `StateManager.swift` | JSON → `~/Library/Application Support/LG NetCast Remote/lg_remote_state.json` |
| `LaunchAgentManager.swift` | Writes/removes `~/Library/LaunchAgents/com.kadelee.lgnetcast.menubar.plist` |

### Adding a new key

Add a `case` to `LGKey` in `KeyMap.swift` with its integer code, then add an `RBtn` call in `RemoteView.swift`.
