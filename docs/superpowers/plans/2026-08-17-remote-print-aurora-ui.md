# Remote Print Aurora UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a bright Aurora Control interface for the macOS remote-print client without changing print, preview, or connection behavior.

**Architecture:** Introduce a small SwiftUI visual-token layer for colors, glass cards, status pills, and primary buttons. Rebuild `SimulatorView` around a large dashboard layout while preserving its existing state actions and sheets.

**Tech Stack:** Swift 6, SwiftUI, AppKit, PDFKit, XCTest, macOS 14.

## Global Constraints

- Support macOS 14 and later.
- Keep all existing Chinese user-facing behavior.
- Default window size is 1440×900.
- Keep all existing local file printing, preview, configuration, and task-state functions intact.
- All primary actions have a minimum 44 pt height.

---

### Task 1: Add Aurora visual tokens

**Files:**
- Create: `outputs/RemotePrintSimulator/Sources/RemotePrintSimulator/AuroraTheme.swift`
- Create: `outputs/RemotePrintSimulator/Sources/RemotePrintCore/AuroraStatusColor.swift`
- Test: `outputs/RemotePrintSimulator/Tests/RemotePrintCoreTests/AuroraThemeTests.swift`

**Produces:** `AuroraStatusColor` in the tested core module plus `AuroraTheme.primaryGradient`, `AuroraTheme.statusColor(_:)`, `AuroraGlassCard`, and `AuroraPrimaryButtonStyle` for the dashboard.

- [ ] **Step 1: Write a failing test**

```swift
func testPrintingStatusUsesBlueAccent() {
    XCTAssertEqual(AuroraStatusColor.printing.rawValue, "#2675FF")
}
```

- [ ] **Step 2: Run the focused XCTest target and verify that it fails because the visual token type does not exist.**

- [ ] **Step 3: Implement the minimal `AuroraStatusColor` enum and SwiftUI visual helpers.**

- [ ] **Step 4: Re-run the focused test and verify it passes.**

### Task 2: Rebuild the main dashboard

**Files:**
- Modify: `outputs/RemotePrintSimulator/Sources/RemotePrintSimulator/SimulatorView.swift`
- Modify: `outputs/RemotePrintSimulator/Sources/RemotePrintSimulator/main.swift`

**Consumes:** Aurora visual helpers from Task 1 and current `AppState` public API.

**Produces:** 1440×900 Aurora dashboard with header, creation card, device metrics, and large task cards.

- [ ] **Step 1: Preserve all `AppState` action calls and rebuild only view composition.**
- [ ] **Step 2: Give task actions 44 pt minimum height and move task status to `AuroraTheme.statusColor(_:)`.**
- [ ] **Step 3: Set the AppKit initial content rectangle to 1440×900.**
- [ ] **Step 4: Build the executable to verify SwiftUI type-checking.**

### Task 3: Verify and package

**Files:**
- Modify: `outputs/RemotePrintSimulator/Remote Print Simulator.app` via `Scripts/package_app.sh`

- [ ] **Step 1: Run the complete `swift test` suite using an isolated scratch path.**
- [ ] **Step 2: Package, sign, and install the App into `/Applications/远程打印模拟器.app`.**
- [ ] **Step 3: Launch the installed App and use accessibility inspection to confirm header, file controls, and task area are visible.**
