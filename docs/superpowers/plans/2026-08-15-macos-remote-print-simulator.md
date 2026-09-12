# macOS Remote Print Simulator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS 14+ native Swift menu-bar simulator that validates remote print jobs without a real cloud service or physical printer.

**Architecture:** A SwiftUI app owns a single observable application state. A local simulated transport creates jobs, validates printer selection, runs confirmation or silent processing, and records acknowledgements. AppKit supplies the available-printer catalog; the first build simulates print completion so it is safe to run anywhere.

**Tech Stack:** Swift 6, SwiftUI, AppKit, XCTest, Xcode.

## Global Constraints

- Minimum deployment target: macOS 14.
- The first version is a simulation: no network listener, credentials, cloud connection, or physical printer output.
- Support PDF, image, label, and receipt job types.
- The task payload selects a named printer; the app rejects missing printers.
- The user setting chooses confirmation-before-printing or silent printing.

---

## File Structure

- `RemotePrintSimulator/RemotePrintSimulatorApp.swift` — application entry and menu-bar scene.
- `RemotePrintSimulator/Models/PrintJob.swift` — job type, lifecycle, acknowledgement, and validation errors.
- `RemotePrintSimulator/Services/PrinterCatalog.swift` — AppKit printer discovery behind a protocol.
- `RemotePrintSimulator/Services/SimulatedTransport.swift` — locally generated jobs and acknowledgement storage.
- `RemotePrintSimulator/AppState.swift` — queue orchestration and confirmation/silent mode behavior.
- `RemotePrintSimulator/Views/SimulatorView.swift` — job composer and activity list.
- `RemotePrintSimulator/Views/SettingsView.swift` — behavior setting and printer status.
- `RemotePrintSimulatorTests/PrintJobTests.swift` — model validation and lifecycle tests.
- `RemotePrintSimulatorTests/AppStateTests.swift` — queue, failure, confirmation, and silent-mode tests.

### Task 1: Create the Swift macOS app and job domain

**Files:**
- Create: `RemotePrintSimulator/RemotePrintSimulatorApp.swift`
- Create: `RemotePrintSimulator/Models/PrintJob.swift`
- Create: `RemotePrintSimulatorTests/PrintJobTests.swift`

**Interfaces:**
- Produces: `enum PrintContentType: String, CaseIterable { case pdf, image, label, receipt }`.
- Produces: `enum PrintJobStatus: String { case received, awaitingConfirmation, printing, succeeded, failed, cancelled }`.
- Produces: `struct PrintJob: Identifiable, Equatable` with `id`, `contentType`, `printerName`, `status`, and `failureReason`.
- Produces: `func validate(availablePrinters: [String]) -> String?`.

- [ ] **Step 1: Write the failing domain tests**

```swift
func testValidationRejectsMissingPrinter() {
    let job = PrintJob(contentType: .pdf, printerName: "Missing")
    XCTAssertEqual(job.validate(availablePrinters: ["Office"]), "The selected printer is unavailable.")
}

func testValidationAcceptsKnownPrinter() {
    let job = PrintJob(contentType: .receipt, printerName: "Office")
    XCTAssertNil(job.validate(availablePrinters: ["Office"]))
}
```

- [ ] **Step 2: Run the tests and confirm they fail because the app domain does not yet exist.**

- [ ] **Step 3: Add the minimal model and validation implementation.**

```swift
func validate(availablePrinters: [String]) -> String? {
    availablePrinters.contains(printerName) ? nil : "The selected printer is unavailable."
}
```

- [ ] **Step 4: Run the domain tests and confirm they pass.**
- [ ] **Step 5: Commit the app scaffold and job domain.**

### Task 2: Add printer discovery and simulated transport

**Files:**
- Create: `RemotePrintSimulator/Services/PrinterCatalog.swift`
- Create: `RemotePrintSimulator/Services/SimulatedTransport.swift`
- Modify: `RemotePrintSimulatorTests/PrintJobTests.swift`

**Interfaces:**
- Consumes: `PrintJob` and `PrintJobStatus` from Task 1.
- Produces: `protocol PrinterCatalog { func printerNames() -> [String] }`.
- Produces: `final class SystemPrinterCatalog: PrinterCatalog`.
- Produces: `final class SimulatedTransport` with `func createJob(contentType: PrintContentType, printerName: String) -> PrintJob` and `func acknowledge(_ job: PrintJob)`.

- [ ] **Step 1: Write tests for generated jobs and retained acknowledgements.**

```swift
func testTransportCreatesReceivedJob() {
    let transport = SimulatedTransport()
    let job = transport.createJob(contentType: .image, printerName: "Office")
    XCTAssertEqual(job.status, .received)
}
```

- [ ] **Step 2: Run the tests and confirm they fail because the transport is absent.**
- [ ] **Step 3: Implement the AppKit-backed catalog and in-memory transport.**

```swift
func printerNames() -> [String] {
    NSPrinter.printerNames.sorted()
}
```

- [ ] **Step 4: Run transport tests and confirm they pass.**
- [ ] **Step 5: Commit printer discovery and simulated transport.**

### Task 3: Implement queue orchestration and behavior modes

**Files:**
- Create: `RemotePrintSimulator/AppState.swift`
- Create: `RemotePrintSimulatorTests/AppStateTests.swift`

**Interfaces:**
- Consumes: `PrintJob`, `PrinterCatalog`, and `SimulatedTransport`.
- Produces: `enum PrintBehavior { case confirm, silent }`.
- Produces: `@MainActor final class AppState: ObservableObject` with `@Published var jobs: [PrintJob]`, `@Published var behavior: PrintBehavior`, `func receive(_:)`, `func approve(jobID:)`, and `func cancel(jobID:)`.

- [ ] **Step 1: Write failing tests for unavailable printers, confirmation, cancellation, and silent success.**

```swift
func testSilentJobCompletesImmediately() async {
    let state = AppState(printerCatalog: StubCatalog(["Office"]))
    state.behavior = .silent
    state.receive(PrintJob(contentType: .label, printerName: "Office"))
    XCTAssertEqual(state.jobs.first?.status, .succeeded)
}
```

- [ ] **Step 2: Run the tests and confirm they fail because `AppState` is absent.**
- [ ] **Step 3: Implement state transitions and acknowledgement updates.**

```swift
if behavior == .confirm {
    update(jobID, status: .awaitingConfirmation)
} else {
    update(jobID, status: .printing)
    update(jobID, status: .succeeded)
}
```

- [ ] **Step 4: Run state tests and confirm they pass.**
- [ ] **Step 5: Commit queue orchestration.**

### Task 4: Build the menu-bar UI and simulator controls

**Files:**
- Modify: `RemotePrintSimulator/RemotePrintSimulatorApp.swift`
- Create: `RemotePrintSimulator/Views/SimulatorView.swift`
- Create: `RemotePrintSimulator/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `AppState`, `PrintContentType`, and `PrintJobStatus`.
- Produces: a menu-bar control that opens the simulator and settings windows.

- [ ] **Step 1: Add a UI smoke-test checklist before implementation:** start app, choose a printer, enqueue each content type, approve one job, cancel one job, switch to silent mode, and submit an unavailable-printer job.
- [ ] **Step 2: Implement the job composer with content-type and printer pickers.**

```swift
Picker("Content", selection: $contentType) {
    ForEach(PrintContentType.allCases, id: \.self) { Text($0.rawValue.capitalized) }
}
```

- [ ] **Step 3: Implement the activity list, behavior setting, and menu-bar status summary.**
- [ ] **Step 4: Run the UI smoke-test checklist and record any failures in the project README.**
- [ ] **Step 5: Commit the user interface.**

### Task 5: Verify the simulator end to end

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: the completed app and test suites.
- Produces: launch instructions and a manual verification checklist.

- [ ] **Step 1: Run all XCTest suites and resolve any failures.**
- [ ] **Step 2: Build the macOS app with the macOS 14 deployment target.**
- [ ] **Step 3: Perform the manual workflow for all four content types in both confirmation and silent modes.**
- [ ] **Step 4: Document setup, simulation limitations, and the real-cloud integration seam in `README.md`.**
- [ ] **Step 5: Commit verification documentation.**
