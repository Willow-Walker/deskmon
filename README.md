# Deskmon

> **Desk**top **Mon**itoring — your servers, at a glance.

**Native macOS menu bar app for monitoring your home servers.**

A lightweight, privacy-first server monitoring tool designed for homelab enthusiasts. See your server stats at a glance without opening a browser or setting up complex monitoring stacks.

![Status](https://img.shields.io/badge/status-in%20development-yellow)
![Platform](https://img.shields.io/badge/platform-macOS-blue)
![License](https://img.shields.io/badge/license-proprietary-red)

---

## Vision

**The problem:** You run a home server (pihole, file storage, Plex, docker containers). Checking on it means SSH-ing in, opening a browser to various dashboards, or setting up heavyweight solutions like Grafana + Prometheus.

**The solution:** A native macOS menu bar app that shows you everything at a glance. One click. No browser. No complexity.

---

## Target Audience

- **Homelab enthusiasts** running personal servers
- **Developers** with local dev servers or VMs
- **Self-hosters** running pihole, Plex, Jellyfin, Home Assistant
- **Mac users** who want native UX, not Electron bloat
- **Privacy-conscious** users who don't want cloud monitoring

### User Persona

> "I run a Linux server at home with pihole, some docker containers, and file storage. I use my Mac for everything else. I just want to glance up at my menu bar and know my server is healthy without context-switching."

---

## Core Features

### Menu Bar App (macOS)

- **Status at a glance**: Green/yellow/red indicator in menu bar
- **Quick dropdown**: Click to see live stats
- **Multi-server support**: Monitor multiple machines
- **Native Swift/SwiftUI**: Fast, lightweight, no Electron
- **Widgets**: Desktop and notification center widgets
- **Alerts**: Get notified when thresholds are exceeded

### Agent (Linux/BSD)

- **Tiny footprint**: Single binary, <5MB, minimal CPU usage
- **Zero config**: Works out of the box
- **Open source**: Inspect what runs on your server
- **Secure**: Binds to local network only, optional auth token

---

## Stats & Metrics

### System (Always Available)

| Metric | Description |
|--------|-------------|
| CPU | Usage percentage, per-core breakdown |
| Memory | Used/total RAM, swap usage |
| Disk | Usage per mount, read/write speeds |
| Network | Upload/download speeds, total transferred |
| Load | 1/5/15 minute load averages |
| Uptime | How long the server has been running |
| Temperature | CPU/GPU temps (where available) |

### Docker Containers

| Metric | Description |
|--------|-------------|
| Status | Running, stopped, restarting |
| CPU | Per-container CPU usage |
| Memory | Per-container memory usage |
| Ports | Exposed port mappings |
| Health | Health check status |

### App Integrations (Planned)

| App | Metrics |
|-----|---------|
| **Pihole** | Queries today, blocked %, top domains |
| **Plex** | Active streams, library stats |
| **Jellyfin** | Active streams, users |
| **Home Assistant** | Entity count, automations |
| **AdGuard Home** | Similar to Pihole |
| **Portainer** | Stacks, containers |
| **Proxmox** | VMs, resource usage |
| **TrueNAS** | Pools, disk health |

---

## Design Philosophy

### Native First
Built with Swift and SwiftUI. Feels like a first-party Apple app. Follows macOS design conventions. Plays nice with system dark mode, accent colors, and accessibility features.

### Privacy First
- All data stays on your network
- No cloud, no accounts, no telemetry
- Agent source code is open for inspection
- Works completely offline

### Simplicity First
- Zero configuration for basic usage
- Install agent → add server IP → done
- Power features available but not required

---

## Pricing Model

### Free Tier
- 1 server
- Core system stats
- 60-second refresh interval

### Pro ($5/month or $80 lifetime)
- Unlimited servers
- Docker container stats
- App integrations (Pihole, Plex, etc.)
- 5-second refresh interval
- Desktop widgets
- Custom alerts
- Priority support

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    macOS Menu Bar App                   │
│                  (Swift/SwiftUI - Closed Source)        │
└───────────────────────┬─────────────────────────────────┘
                        │ HTTP/JSON (LAN)
                        ▼
┌─────────────────────────────────────────────────────────┐
│                    Deskmon Agent                          │
│                  (Go - Open Source)                     │
│  ┌─────────────┬─────────────┬─────────────────────┐   │
│  │   System    │   Docker    │    Integrations     │   │
│  │  Collector  │  Collector  │  (Pihole, Plex...)  │   │
│  └─────────────┴─────────────┴─────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Communication

1. Agent runs on server, binds to `0.0.0.0:7654`
2. macOS app polls agent every N seconds over HTTP
3. Optional: WebSocket for real-time updates (v2)
4. Optional: Auth token for security

### Agent Endpoints

```
GET /health          → { "status": "ok" }
GET /stats           → Full system stats JSON
GET /stats/system    → CPU, RAM, disk, network only
GET /stats/docker    → Container stats only
GET /stats/pihole    → Pihole integration stats
```

---

## UI Mockup

```
┌──────────────────────────────────────┐
│ prowl-server               12d  │
├──────────────────────────────────────┤
│                                      │
│  CPU   ████████░░░░░░░░  48%        │
│  RAM   ██████████████░░  87%  14GB  │
│  Disk  ████████░░░░░░░░  52%  240G  │
│  Net   ↓ 12.4 MB/s   ↑ 1.2 MB/s    │
│                                      │
├──────────────────────────────────────┤
│  Containers (6)                   │
│                                      │
│   ● pihole         0.5%     128MB   │
│   ● plex          12.3%     2.1GB   │
│   ● homebridge     0.1%      64MB   │
│   ● jellyfin       2.1%     512MB   │
│   ● homeassistant  1.8%     384MB   │
│   ○ nginx         stopped           │
│                                      │
├──────────────────────────────────────┤
│  Pihole                           │
│   Queries: 45.6k   Blocked: 27.3%   │
│   Status: Enabled                    │
│                                      │
├──────────────────────────────────────┤
│  Settings    Add Server        │
└──────────────────────────────────────┘
```

---

## Roadmap

### Phase 1: MVP (Weeks 1-5)
- [ ] Agent: Core system stats (CPU, RAM, disk, network)
- [ ] Agent: Docker container stats
- [ ] Agent: HTTP server with JSON API
- [ ] Agent: Install script (curl | bash)
- [ ] macOS: Menu bar icon with status color
- [ ] macOS: Dropdown with live stats
- [ ] macOS: Add/remove servers
- [ ] macOS: Basic settings

### Phase 2: Integrations (Weeks 6-8)
- [ ] Agent: Pihole integration
- [ ] Agent: Plex integration
- [ ] Agent: Config file for integrations
- [ ] macOS: Integration UI
- [ ] macOS: Desktop widgets

### Phase 3: Polish (Weeks 9-10)
- [ ] macOS: Alert thresholds & notifications
- [ ] macOS: Keyboard shortcuts
- [ ] Landing page & docs
- [ ] Payment integration (Gumroad/Paddle)
- [ ] TestFlight beta

### Phase 4: Expansion (Future)
- [ ] More integrations (Jellyfin, Home Assistant, Proxmox)
- [ ] iOS companion app
- [ ] Historical data & graphs
- [ ] Multi-user / family sharing

---

## Tech Stack

### Agent
- **Language**: Go
- **Dependencies**: Minimal (stdlib + docker client)
- **Build**: Static binary, cross-compiled for Linux (amd64, arm64)
- **Distribution**: GitHub releases, install script

### macOS App
- **Language**: Swift 5.9+
- **UI**: SwiftUI
- **Target**: macOS 14 (Sonoma)+
- **Distribution**: Direct download, potentially Mac App Store

---

## Repository Structure

```
deskmon/
├── agent/                 # Go agent (open source)
│   ├── cmd/
│   │   └── deskmon-agent/
│   ├── internal/
│   │   ├── collectors/
│   │   ├── integrations/
│   │   └── server/
│   ├── go.mod
│   └── Makefile
│
├── app/                   # macOS app (closed source, separate repo)
│   └── (in separate private repo)
│
├── docs/                  # Documentation
│   ├── installation.md
│   ├── configuration.md
│   └── integrations/
│
├── website/               # Landing page
│   └── (static site)
│
└── README.md
```

---

## Competition & Differentiation

| Feature | Deskmon | iStatMenus | Beszel | Zabbix Monitor |
|---------|-------|------------|--------|----------------|
| Remote servers | ✅ | ❌ | ✅ | ✅ |
| macOS native | ✅ | ✅ | ❌ | ✅ |
| No backend required | ✅ | ✅ | ✅ | ❌ |
| Docker stats | ✅ | ❌ | ✅ | ✅ |
| App integrations | ✅ | ❌ | ❌ | via Zabbix |
| Open source agent | ✅ | N/A | ✅ | N/A |
| Menu bar | ✅ | ✅ | ❌ | ✅ |

---

## License

- **Agent**: MIT (open source)
- **macOS App**: Proprietary (closed source)

---

*Built for homelab enthusiasts who just want to know their server is okay.*
