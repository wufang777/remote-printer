# Office 与 WPS 打印实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在远程打印链路中支持 Office 与 WPS 文件，并提供可配置的确认后打印策略。

**Architecture:** Node 中转站和 Swift 发送端共享格式集合；macOS 控制台将远端内容类型扩展为 office/wps，并由独立文档处理器在用户确认时进行转换或本机应用直印。

**Tech Stack:** Node.js/Express/Node test；Swift 6/AppKit/SwiftUI/XCTest/macOS 14。

**Spec:** `docs/superpowers/specs/2026-09-11-office-wps-printing-design.md`

## Global Constraints

- 格式为 `pdf,jpg,jpeg,png,doc,docx,xls,xlsx,ppt,pptx,wps,et,dps`，最大 25 MB。
- 打印任务必须在控制台显示并由用户确认后执行。
- 默认策略为 `automatic`；不自动安装第三方转换器。
- 新增文件须有中文界面文案和自动化测试。

---

### Task 1: 发送与中转格式分类

**Files:**
- Modify: `outputs/RemotePrintRelay/src/app.js`
- Modify: `outputs/RemotePrintRelay/test/sender-api.test.js`
- Modify: `outputs/RemotePrintSender/Sources/RemotePrintSenderCore/RelaySenderClient.swift`
- Modify: `outputs/RemotePrintSender/Sources/RemotePrintSender/SenderView.swift`
- Test: `outputs/RemotePrintSender/Tests/RemotePrintSenderCoreTests/RelaySenderClientTests.swift`

- [ ] **Step 1: Write failing Node test**

```js
test('uploads an Office document', async () => {
  const response = await request(app).post('/sender/jobs')
    .field('deviceId', device.deviceId).field('printerName', 'Office')
    .attach('file', Buffer.from('document'), '报价单.docx').expect(201);
  assert.equal(response.body.status, 'queued');
});
```

- [ ] **Step 2: Run red test**

Run: `npm test -- --test-name-pattern="uploads an Office document"`

Expected: 400 `INVALID_FILE`.

- [ ] **Step 3: Implement extension categories**

Add a `fileCategory(fileName)` helper returning `pdf`, `image`, `office`, or `wps`; validate it on upload and return it from `print-jobs:claim`.

- [ ] **Step 4: Run Node suite**

Run: `npm test`

Expected: PASS.

### Task 2: macOS remote validation and models

**Files:**
- Modify: `outputs/RemotePrintSimulator/Sources/RemotePrintCore/RemotePrintAPIModels.swift`
- Modify: `outputs/RemotePrintSimulator/Sources/RemotePrintCore/RemotePrintFileValidator.swift`
- Modify: `outputs/RemotePrintSimulator/Sources/RemotePrintCore/RemotePrintAPIClient.swift`
- Test: `outputs/RemotePrintSimulator/Tests/RemotePrintCoreTests/RemotePrintFileValidatorTests.swift`
- Test: `outputs/RemotePrintSimulator/Tests/RemotePrintCoreTests/RemotePrintAPIClientTests.swift`

- [ ] **Step 1: Write failing validator test**

```swift
func testAcceptsDownloadedOfficeDocument() throws {
    let file = try fixture(named: "quote.docx")
    XCTAssertNoThrow(try RemotePrintFileValidator.validate(downloadedFile: file, expectedSHA256: sha256(file), contentType: .office))
}
```

- [ ] **Step 2: Run red test**

Run: `swift test --filter RemotePrintFileValidatorTests`

Expected: compile error because `.office` is undefined.

- [ ] **Step 3: Implement minimal model change**

Add `office` and `wps` cases, map both to new `PrintContentType.document`, and advertise all four remote formats in the claim request.

- [ ] **Step 4: Run focused tests**

Run: `swift test --filter RemotePrintFileValidatorTests`

Expected: PASS.

### Task 3: Confirmed document print strategies

**Files:**
- Create: `outputs/RemotePrintSimulator/Sources/RemotePrintCore/DocumentPrintStrategy.swift`
- Create: `outputs/RemotePrintSimulator/Sources/RemotePrintSimulator/DocumentPrintService.swift`
- Modify: `outputs/RemotePrintSimulator/Sources/RemotePrintSimulator/LocalFilePrinter.swift`
- Modify: `outputs/RemotePrintSimulator/Sources/RemotePrintSimulator/SimulatorView.swift`
- Modify: `outputs/RemotePrintSimulator/Sources/RemotePrintSimulator/SettingsView.swift`
- Test: `outputs/RemotePrintSimulator/Tests/RemotePrintCoreTests/DocumentPrintStrategyTests.swift`

- [ ] **Step 1: Write failing settings-default test**

```swift
func testDefaultDocumentStrategyIsAutomatic() {
    XCTAssertEqual(DocumentPrintStrategy.defaultValue, .automatic)
}
```

- [ ] **Step 2: Run red test**

Run: `swift test --filter DocumentPrintStrategyTests`

Expected: compile error because the strategy is undefined.

- [ ] **Step 3: Implement strategy and service**

Create enum cases `nativeApplication`, `convertToPDF`, `automatic`. The service finds `soffice`/`libreoffice` for conversion; native mode chooses WPS Office for WPS and Microsoft Office application by extension for Office; returns Chinese failure text if no handler exists. `automatic` attempts conversion then native application.

- [ ] **Step 4: Wire confirmation action**

Route document jobs only after `approve(jobID:)`. PDF/image behavior stays unchanged. Persist the strategy in `UserDefaults` and expose it in settings.

- [ ] **Step 5: Run simulator suite and package**

Run: `swift test` then `zsh Scripts/package_app.sh`.

Expected: tests pass and signed `.app` is rebuilt.

### Task 4: Sender UI and operating guide

**Files:**
- Modify: `outputs/RemotePrintSender/Sources/RemotePrintSender/SenderView.swift`
- Modify: `outputs/RemotePrintSender/README.md`
- Modify: `outputs/RemotePrintSimulator/docs/API_V1.md`

- [ ] **Step 1: Update file picker and copy**

Expose Office/WPS formats in the importer and list supported types in Chinese.

- [ ] **Step 2: Document conversion requirements**

Explain the three strategies, required installed applications and behavior when LibreOffice is unavailable.

- [ ] **Step 3: Final verification**

Run Node and both Swift test suites; package both macOS apps; ensure documentation contains no incomplete markers.
