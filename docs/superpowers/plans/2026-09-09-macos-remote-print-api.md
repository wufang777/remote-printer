# macOS Remote Print API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add secure API v1 registration, task retrieval, file download, checksum validation and event reporting to the macOS remote-print client.

**Architecture:** `RemotePrintAPIClient` owns URLSession JSON and signed-file requests. `DeviceCredentialStore` owns Keychain secrets and `RemotePrintCoordinator` owns registration, printer synchronization, polling and delivery into `AppState`; `AppState` remains the single source of UI-visible print state.

**Tech Stack:** Swift 6, Swift Package Manager, XCTest, Foundation URLSession/CryptoKit, Security Keychain, macOS 14.

**Spec:** `docs/superpowers/specs/2026-09-09-macos-remote-print-api-design.md`

## Global Constraints

- Target macOS 14 or later and preserve existing local-file printing behavior.
- Use API v1 at `outputs/RemotePrintSimulator/docs/API_V1.md`; only HTTPS base URLs and signed HTTPS downloads are accepted.
- Store `deviceId`, token and expiry in Keychain; never in UserDefaults or diagnostic output.
- Support remote PDF, JPG, JPEG and PNG only; verify SHA-256 before printing.
- Keep the client pull-only: no inbound listener or public port.
- Remote print uses current confirm/silent setting; never auto-retry a job after it was submitted to macOS.

---

### Task 1: API data models and content validation

**Files:**
- Create: `outputs/RemotePrintSimulator/Sources/RemotePrintCore/RemotePrintAPIModels.swift`
- Create: `outputs/RemotePrintSimulator/Sources/RemotePrintCore/RemotePrintFileValidator.swift`
- Create: `outputs/RemotePrintSimulator/Tests/RemotePrintCoreTests/RemotePrintFileValidatorTests.swift`

**Interfaces:**
- Produces `RemotePrintJob`, `RemotePrintEvent`, `RemotePrintFailureCode`, and `RemotePrintFileValidator.validate(downloadedFile:expectedSHA256:contentType:) throws -> URL`.

- [ ] **Step 1: Write failing validator tests**

```swift
func testValidatorAcceptsMatchingPDFChecksum() throws {
    let file = try temporaryFile(named: "order.pdf", contents: Data("pdf".utf8))
    XCTAssertNoThrow(try RemotePrintFileValidator.validate(downloadedFile: file, expectedSHA256: sha256(of: Data("pdf".utf8)), contentType: .pdf))
}

func testValidatorRejectsChecksumMismatch() throws {
    let file = try temporaryFile(named: "order.pdf", contents: Data("pdf".utf8))
    XCTAssertThrowsError(try RemotePrintFileValidator.validate(downloadedFile: file, expectedSHA256: String(repeating: "0", count: 64), contentType: .pdf))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter RemotePrintFileValidatorTests`

Expected: FAIL because `RemotePrintFileValidator` is undefined.

- [ ] **Step 3: Implement models and validator**

```swift
public enum RemoteContentType: String, Codable, Sendable { case pdf, image }
public enum RemotePrintValidationError: Error { case unsupportedFile, checksumMismatch }
public static func validate(downloadedFile: URL, expectedSHA256: String, contentType: RemoteContentType) throws -> URL
```

Use CryptoKit `SHA256.hash(data:)`, require a 64-character lowercase hexadecimal checksum, and accept only PDF for `.pdf` and images for `.jpg`, `.jpeg`, `.png`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter RemotePrintFileValidatorTests`

Expected: PASS.

### Task 2: Keychain credential storage

**Files:**
- Create: `outputs/RemotePrintSimulator/Sources/RemotePrintCore/DeviceCredentialStore.swift`
- Create: `outputs/RemotePrintSimulator/Tests/RemotePrintCoreTests/DeviceCredentialTests.swift`

**Interfaces:**
- Produces `DeviceCredentials(deviceID:accessToken:expiresAt:)` and `DeviceCredentialStoring.load() throws -> DeviceCredentials?`, `save(_:) throws`, `delete() throws`.

- [ ] **Step 1: Write failing in-memory-store tests**

```swift
func testSavedCredentialsCanBeReadBack() throws {
    let store = InMemoryCredentialStore()
    let credentials = DeviceCredentials(deviceID: "dev_1", accessToken: "secret", expiresAt: .distantFuture)
    try store.save(credentials)
    XCTAssertEqual(try store.load(), credentials)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DeviceCredentialTests`

Expected: FAIL because credential types do not exist.

- [ ] **Step 3: Implement credential protocol and Keychain store**

```swift
public protocol DeviceCredentialStoring: Sendable {
    func load() throws -> DeviceCredentials?
    func save(_ credentials: DeviceCredentials) throws
    func delete() throws
}
```

Use `kSecClassGenericPassword`, a fixed service identifier, and one JSON-encoded credential value. Map non-success Security statuses to a typed error without exposing the token.

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter DeviceCredentialTests`

Expected: PASS.

### Task 3: URLSession API client

**Files:**
- Create: `outputs/RemotePrintSimulator/Sources/RemotePrintCore/RemotePrintAPIClient.swift`
- Create: `outputs/RemotePrintSimulator/Tests/RemotePrintCoreTests/RemotePrintAPIClientTests.swift`

**Interfaces:**
- Produces `RemotePrintAPIClient.register(configuration:)`, `syncPrinters(deviceID:token:printers:)`, `claimJobs(deviceID:token:printers:)`, `download(_:)`, and `postEvent(deviceID:token:taskID:event:)`.

- [ ] **Step 1: Write failing URLProtocol request tests**

```swift
func testRegisterSendsActivationCodeAndDecodesCredentials() async throws {
    let client = RemotePrintAPIClient(session: stubbedSession)
    let response = try await client.register(configuration: configuration)
    XCTAssertEqual(response.deviceID, "dev_1")
    XCTAssertEqual(stubbedRequest.httpMethod, "POST")
    XCTAssertEqual(stubbedRequest.url?.path, "/v1/devices/register")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter RemotePrintAPIClientTests`

Expected: FAIL because API client is undefined.

- [ ] **Step 3: Implement client and response checks**

Use URLSession async APIs, JSON encoding/decoding, Accept and Content-Type headers, Bearer authorization only for API paths, 2xx success enforcement, no HTTP redirect for signed downloads, and a 25 MB maximum file response.

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter RemotePrintAPIClientTests`

Expected: PASS.

### Task 4: Coordinator and AppState event bridge

**Files:**
- Create: `outputs/RemotePrintSimulator/Sources/RemotePrintCore/RemotePrintCoordinator.swift`
- Modify: `outputs/RemotePrintSimulator/Sources/RemotePrintCore/AppState.swift`
- Create: `outputs/RemotePrintSimulator/Tests/RemotePrintCoreTests/RemotePrintCoordinatorTests.swift`

**Interfaces:**
- Produces `RemotePrintCoordinator.start(configuration:)`, `stop()`, `refreshNow()`, `report(jobID:status:failure:)`.
- Modifies `AppState` to identify remote jobs and report every state transition through a callback without calling remote APIs for local jobs.

- [ ] **Step 1: Write failing coordinator tests**

```swift
func testClaimedJobWithAvailablePrinterEntersConfirmationQueue() async throws {
    let coordinator = makeCoordinator(behavior: .confirm, claimedJobs: [remotePDFJob])
    await coordinator.refreshNow()
    XCTAssertEqual(await coordinator.jobs.first?.status, .awaitingConfirmation)
    XCTAssertEqual(await coordinator.events.map(\.status), [.received, .awaitingConfirmation])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter RemotePrintCoordinatorTests`

Expected: FAIL because coordinator is undefined.

- [ ] **Step 3: Implement coordinator**

Register if Keychain is empty or expired, sync printers at start, claim no more than five jobs, download/validate to `cachesDirectory/RemotePrintJobs`, map failures to API v1 failure codes, and schedule retries at 10/20/40/60 seconds. Keep polling disabled when configuration is invalid.

- [ ] **Step 4: Implement AppState bridge and run focused tests**

Run: `swift test --filter 'AppStateTests|RemotePrintCoordinatorTests'`

Expected: PASS; existing local jobs generate no remote events.

### Task 5: Settings and UI connection controls

**Files:**
- Modify: `outputs/RemotePrintSimulator/Sources/RemotePrintSimulator/ConnectionSettingsView.swift`
- Modify: `outputs/RemotePrintSimulator/Sources/RemotePrintSimulator/SimulatorView.swift`
- Modify: `outputs/RemotePrintSimulator/Sources/RemotePrintSimulator/main.swift`
- Create: `outputs/RemotePrintSimulator/Tests/RemotePrintCoreTests/RemotePollScheduleTests.swift`

**Interfaces:**
- UI consumes coordinator connection state (`disconnected`, `connecting`, `connected`, `retrying`) and provides a “连接/断开” action.

- [ ] **Step 1: Write failing poll schedule tests**

```swift
func testRetryScheduleCapsAtSixtySeconds() {
    XCTAssertEqual(RemotePollSchedule.delay(afterFailureCount: 5), 60)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter RemotePollScheduleTests`

Expected: FAIL because `RemotePollSchedule` is undefined.

- [ ] **Step 3: Implement connection ownership and controls**

Create one coordinator in app startup, inject it into `AppState`/SwiftUI environment, show Chinese connection state in the Aurora header, and make “连接” validate and save settings before starting. “断开” stops polling but retains Keychain credentials until the user replaces configuration.

- [ ] **Step 4: Run the complete test suite and package**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer zsh Scripts/package_app.sh
```

Expected: all tests pass and the macOS `.app` packages successfully.

### Task 6: Documentation and manual verification

**Files:**
- Modify: `outputs/RemotePrintSimulator/docs/API_V1.md`
- Create: `outputs/RemotePrintSimulator/docs/REMOTE_API_TESTING.md`

**Interfaces:**
- Documents exact test configuration, expected event sequence and platform integration checklist.

- [ ] **Step 1: Document test-server contract and manual checks**

Include HTTPS base URL, test activation code, sample printer names, expected signed-download URL behavior, retry verification and “存储为 PDF” workflow.

- [ ] **Step 2: Validate documentation links and final app launch**

Run: `rg -n 'http://|TODO|TBD' docs`

Expected: no production API configuration permits HTTP; no unfinished documentation markers.

