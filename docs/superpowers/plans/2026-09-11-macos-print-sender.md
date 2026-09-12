# macOS 打印文件发送端实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个中文 macOS SwiftUI 发送端 App，手动选择一个文件并通过本地中转站提交到远程打印控制台。

**Architecture:** Node 中转站增加设备/打印机只读路由；Swift App 使用 `RelaySenderClient` 请求本机 API，`SenderState` 管理选择、上传和状态轮询，`SenderView` 仅负责 Aurora UI。

**Tech Stack:** Node.js/Express/Multer/Node test runner；Swift 6/SwiftUI/URLSession/XCTest/macOS 14。

**Spec:** `docs/superpowers/specs/2026-09-11-macos-print-sender-design.md`

## Global Constraints

- App 与中转站只允许 `127.0.0.1:17880`；不使用远程或公网地址。
- 单文件 PDF/JPG/JPEG/PNG，最大 25 MB。
- 默认 App 窗口 1100×760，简体中文 Aurora UI。
- 不保存文件、设备令牌或打印机凭证。

---

### Task 1: 中转站只读设备接口

**Files:**
- Modify: `outputs/RemotePrintRelay/src/app.js`
- Create: `outputs/RemotePrintRelay/test/sender-devices-api.test.js`

- [ ] **Step 1: Write failing route test**

```js
const devices = await request(app).get('/sender/devices').expect(200);
assert.equal(devices.body.devices[0].deviceName, 'Test Mac');
const printers = await request(app).get(`/sender/devices/${deviceId}/printers`).expect(200);
assert.equal(printers.body.printers[0].name, 'Office');
```

- [ ] **Step 2: Run red test**

Run: `npm test -- --test-name-pattern="lists synchronized printers"`

Expected: FAIL with 404.

- [ ] **Step 3: Implement routes**

Expose device ID/name only; return printer name, online and default fields; unknown device returns 404.

- [ ] **Step 4: Run Node suite**

Run: `npm test`

Expected: PASS.

### Task 2: Swift client models and loopback validation

**Files:**
- Create: `outputs/RemotePrintSender/Package.swift`
- Create: `outputs/RemotePrintSender/Sources/RemotePrintSenderCore/RelaySenderClient.swift`
- Create: `outputs/RemotePrintSender/Tests/RemotePrintSenderCoreTests/RelaySenderClientTests.swift`

- [ ] **Step 1: Write failing client validation tests**

```swift
func testRejectsNonLoopbackRelayURL() {
    XCTAssertThrowsError(try RelaySenderClient(baseURL: URL(string: "http://192.168.1.2:17880")!))
}
```

- [ ] **Step 2: Run red test**

Run: `swift test --filter RelaySenderClientTests`

Expected: FAIL because client is undefined.

- [ ] **Step 3: Implement models and client**

Provide `loadDevices()`, `loadPrinters(deviceID:)`, `send(fileURL:deviceID:printerName:)`, `job(taskID:)`; enforce loopback host/port and multipart upload.

- [ ] **Step 4: Run focused tests**

Run: `swift test --filter RelaySenderClientTests`

Expected: PASS.

### Task 3: App state and Aurora sender UI

**Files:**
- Create: `outputs/RemotePrintSender/Sources/RemotePrintSenderCore/SenderState.swift`
- Create: `outputs/RemotePrintSender/Sources/RemotePrintSender/SenderView.swift`
- Create: `outputs/RemotePrintSender/Sources/RemotePrintSender/main.swift`
- Create: `outputs/RemotePrintSender/Sources/RemotePrintSender/AuroraTheme.swift`

- [ ] **Step 1: Write failing SenderState test**

```swift
func testSenderStateDisablesSendWithoutFileAndPrinter() async {
    let state = await SenderState(client: stubClient)
    XCTAssertFalse(await state.canSend)
}
```

- [ ] **Step 2: Run red test**

Run: `swift test --filter SenderStateTests`

Expected: FAIL because SenderState is undefined.

- [ ] **Step 3: Implement state and UI**

Load devices on appear, load printers on device choice, offer file importer/preview/delete, upload button, task status card and 3-second terminal-state polling.

- [ ] **Step 4: Build and package**

Run: `swift test` and package the app into `outputs/RemotePrintSender/Remote Print Sender.app`.

Expected: tests pass and App launches.

### Task 4: Manual integration guide

**Files:**
- Create: `outputs/RemotePrintSender/README.md`

- [ ] **Step 1: Document startup and acceptance**

Include starting the relay, opening sender, choosing a device/printer, sending a file and checking remote printing status.

- [ ] **Step 2: Validate no incomplete markers**

Run: `rg -n 'TODO|TBD' README.md`

Expected: no matches.
