## Network Session Debug (SuperBLT)

Host-focused network telemetry HUD for PAYDAY 2.

### Features
- Per-peer ping from `Network:qos(rpc).ping`
- Jitter (EWMA of ping delta)
- Send queue (best-effort via `Network:get_connection_send_status(rpc)`)
- State flags: host/loading/synced/ip_verified/modded/VR + drop-in progress
- Join/leave/kick/loading/sync event feed
- One-key dump of session + peers to SuperBLT log

### Requirements
- PAYDAY 2
- SuperBLT

### Install
Put the `Network_Session_Debug` folder into: `PAYDAY 2/mods/`

### Keybinds
Options → SuperBLT → Keybinds
- Network Session Debug: Toggle HUD
- Network Session Debug: Toggle Mode
- Network Session Debug: Dump Session
- Network Session Debug: Toggle HUD Edit

### HUD Layout
Options → SuperBLT → Options / Settings → Network Session Debug
- HUD X/Y, Anchor, Scale, Alpha
- HUD layout: edit mode (live edit with arrows; Ctrl+Arrows scale/alpha; Shift fast)

### Notes
Some metrics are best-effort and depend on the current networking backend and whether a peer has an active RPC connection.