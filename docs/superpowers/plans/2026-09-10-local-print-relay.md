# 本地远程打印测试中转站实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 127.0.0.1:17880 提供业务软件上传接口和 macOS 打印客户端兼容 API，以测试完整远程打印链路。

**Architecture:** Express 应用仅绑定回环地址。`RelayStore` 用 JSON 和本地文件保存设备与任务，路由层分别提供 `/sender` 业务入口和 `/v1` 客户端兼容入口。

**Tech Stack:** Node.js 26, Express, Multer, Node `crypto`, Node test runner。

**Spec:** `docs/superpowers/specs/2026-09-10-local-print-relay-design.md`

## Global Constraints

- 仅监听 `127.0.0.1:17880`，不可绑定局域网或公网地址。
- 仅接受 PDF/JPG/JPEG/PNG，上传文件不超过 25 MB。
- 数据保存在 `outputs/RemotePrintRelay/data/`，不含真实生产认证。
- 客户端本地 HTTP 例外仅允许 `http://127.0.0.1:17880`；其他 API 和文件 URL 必须 HTTPS。
- 任务只能被目标设备领取一次。

---

### Task 1: 项目骨架和持久化任务仓库

**Files:**
- Create: `outputs/RemotePrintRelay/package.json`
- Create: `outputs/RemotePrintRelay/src/relay-store.js`
- Create: `outputs/RemotePrintRelay/test/relay-store.test.js`

**Interfaces:**
- Produces `RelayStore.registerDevice()`, `savePrinters()`, `createJob()`, `claimJobs()`, `appendEvent()` and `getJob()`.

- [ ] **Step 1: Write the failing repository test**

```js
test('a job can only be claimed once by its target device', async () => {
  const store = await RelayStore.create(tempDirectory);
  const device = await store.registerDevice({ activationCode: 'RP-1', deviceName: 'Test Mac' });
  await store.savePrinters(device.deviceId, [{ name: 'Office', isOnline: true }]);
  const job = await store.createJob({ deviceId: device.deviceId, printerName: 'Office', file: fixture });
  assert.equal((await store.claimJobs(device.deviceId)).length, 1);
  assert.equal((await store.claimJobs(device.deviceId)).length, 0);
});
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `npm test -- --test-name-pattern="claimed once"`

Expected: FAIL because `RelayStore` does not exist.

- [ ] **Step 3: Implement JSON store and atomic claim state**

Persist `devices.json` and `jobs.json`; save uploaded files below `data/files/<taskId>/`; set `claimedBy` before returning a job.

- [ ] **Step 4: Run repository tests**

Run: `npm test -- --test-name-pattern="claimed once"`

Expected: PASS.

### Task 2: 发送端上传和查询接口

**Files:**
- Create: `outputs/RemotePrintRelay/src/app.js`
- Create: `outputs/RemotePrintRelay/test/sender-api.test.js`

**Interfaces:**
- Produces `createApp({ store, uploadDirectory })` with `POST /sender/jobs` and `GET /sender/jobs/:taskId`.

- [ ] **Step 1: Write the failing multipart upload test**

```js
const response = await request(app)
  .post('/sender/jobs')
  .field('deviceId', device.deviceId)
  .field('printerName', 'Office')
  .attach('file', fixturePDF);
assert.equal(response.status, 201);
assert.equal(response.body.status, 'queued');
```

- [ ] **Step 2: Run test and confirm it fails**

Run: `npm test -- --test-name-pattern="uploads a supported file"`

Expected: FAIL because the sender route does not exist.

- [ ] **Step 3: Implement upload validation**

Use Multer with 25 MB limit; validate extension, target device and its synchronized printer. Hash accepted file using SHA-256 and return `201` with task ID.

- [ ] **Step 4: Run sender API tests**

Run: `npm test -- --test-name-pattern="uploads a supported file"`

Expected: PASS.

### Task 3: API v1 compatibility routes

**Files:**
- Modify: `outputs/RemotePrintRelay/src/app.js`
- Create: `outputs/RemotePrintRelay/test/client-api.test.js`

**Interfaces:**
- Produces API v1 registration, printer sync, claim, file serving and event routes defined in `outputs/RemotePrintSimulator/docs/API_V1.md`.

- [ ] **Step 1: Write failing client contract test**

```js
const registration = await request(app).post('/v1/devices/register').send({ activationCode: 'RP-1', deviceName: 'Test Mac', platform: 'macOS' });
await request(app).put(`/v1/devices/${registration.body.deviceId}/printers`).send({ printers: [{ name: 'Office', isOnline: true }] }).expect(204);
const claim = await request(app).post(`/v1/devices/${registration.body.deviceId}/print-jobs:claim`).set('Authorization', `Bearer ${registration.body.accessToken}`).send({ maxJobs: 5, availablePrinters: ['Office'] });
assert.equal(claim.body.jobs[0].printerName, 'Office');
```

- [ ] **Step 2: Run test and confirm it fails**

Run: `npm test -- --test-name-pattern="client can register"`

Expected: FAIL because API v1 routes do not exist.

- [ ] **Step 3: Implement all API v1 routes**

Return local file URLs, 401 on invalid device token, 404 for unknown files, and append client event payloads to the job event timeline.

- [ ] **Step 4: Run all Node tests**

Run: `npm test`

Expected: PASS.

### Task 4: macOS local HTTP allowance and end-to-end manual test

**Files:**
- Modify: `outputs/RemotePrintSimulator/Sources/RemotePrintCore/ConnectionConfiguration.swift`
- Modify: `outputs/RemotePrintSimulator/Sources/RemotePrintCore/RemotePrintAPIClient.swift`
- Create: `outputs/RemotePrintRelay/README.md`

- [ ] **Step 1: Write failing loopback URL test**

```swift
func testAcceptsOnlyTheConfiguredLoopbackTestEndpoint() {
  XCTAssertNil(ConnectionConfiguration(apiBaseURL: "http://127.0.0.1:17880/v1", deviceName: "Test", activationCode: "RP-1").validationError)
  XCTAssertNotNil(ConnectionConfiguration(apiBaseURL: "http://192.168.1.2/v1", deviceName: "Test", activationCode: "RP-1").validationError)
}
```

- [ ] **Step 2: Run test and confirm it fails**

Run: `swift test --filter ConnectionConfigurationTests`

Expected: FAIL because loopback HTTP is currently rejected.

- [ ] **Step 3: Implement strict loopback-only exception and write README**

Allow HTTP only where host is `127.0.0.1`, port is `17880`, and path begins `/v1`; retain HTTPS enforcement everywhere else. Document startup, curl upload and App configuration steps.

- [ ] **Step 4: Validate Node and Swift tests**

Run: `npm test` and `swift test`.

Expected: both suites PASS.
