# Service Connecting Visuals

**Date:** 2026-02-14
**Status:** Approved

## Problem

Three visual gaps when services are loading or reconnecting:

1. **Initial discovery** — After server goes live, `services` is empty until the first SSE services event (~10s). The current empty state shows "No Services" with no indication that discovery is in progress.
2. **Card loading** — Service cards snap in instantly with no entrance animation.
3. **Reconnecting** — When the SSE stream drops and reconnects, stale service cards show no visual feedback that data is outdated.

## Design

### 1. Discovering Services State

**When:** `connectionPhase == .live` AND `services.isEmpty` AND `lastServicesUpdate == nil`

Replace the "No Services" empty state with a discovering state:
- Pulsing `network` SF Symbol
- "Discovering Services..." headline
- Caption: "Scanning for Pi-hole, Traefik, Nginx..."
- Small `ProgressView` spinner

If `lastServicesUpdate != nil` and services are still empty, keep the existing "No Services" state (agent scanned and found nothing).

**Files:** `ServicesGridView.swift`

### 2. Service Card Fade-In

Add `.transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.95)), removal: .opacity))` on each `ServiceCardView` in the grid's `ForEach`.

The existing `withAnimation` in `ServerManager.swift` already wraps `server.services` assignment, so SwiftUI will animate the insertions automatically.

**Files:** `ServicesGridView.swift`

### 3. Reconnecting Overlay

**When:** `server.status == .offline` AND `server.hasConnectedOnce == true`

- Show a subtle HStack banner above the services grid: spinner + "Reconnecting..." in `.secondary`
- Reduce service cards opacity to `0.5` to signal staleness
- When connection restores and new data arrives, overlay disappears, cards return to full opacity

**Files:** `ServicesGridView.swift` (new params: `isReconnecting: Bool`), call site in `DashboardView.swift`

## Files Changed

| File | Change |
|------|--------|
| `ServicesGridView.swift` | Add discovering state, card transitions, reconnecting overlay, new `isReconnecting` + `hasReceivedServices` params |
| `DashboardView.swift` | Pass `isReconnecting` and `hasReceivedServices` to `ServicesGridView` |
