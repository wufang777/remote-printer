# macOS 远程打印 API 接入设计

## 目标

将现有 macOS Aurora Control 从本地文件模拟器扩展为安全的远程打印客户端。客户端主动连接既有平台，注册设备、同步打印机、领取任务、下载并校验 PDF/图片、按本机确认或静默设置打印，再回传状态。

## 范围与约束

- 平台为 macOS 14 及以上；不开放任何公网入站端口。
- 采用现有 `outputs/RemotePrintSimulator/docs/API_V1.md` 的 v1 合约。
- 第一阶段远程内容仅支持 PDF、JPG、JPEG、PNG；标签和票据由平台预生成 PDF。
- 配置页面继续保存 API 地址、设备名称、注册码和本地打印方式。API 地址必须为 HTTPS。
- `deviceId` 与访问令牌仅保存到 macOS Keychain；任务文件仅保存到应用缓存目录，成功或失败后可清理。
- 本地文件选择、预览和打印功能不改变。

## 组件

### RemotePrintAPIClient

负责 URLSession HTTP 调用与 v1 JSON 编解码，接口包括注册、打印机同步、领取任务、事件回传及签名 URL 文件下载。所有 API 请求以 `Authorization: Bearer <token>` 认证；文件签名 URL 不添加该请求头。

### DeviceCredentialStore

使用 macOS Keychain 存取 `deviceId`、`accessToken` 和过期时间。没有凭证或凭证过期时，使用配置中的注册码重新注册。令牌不得出现在 UI、日志或普通 `UserDefaults` 中。

### RemotePrintCoordinator

一个 MainActor 协调器：启动时注册/恢复设备、同步打印机、以服务端建议间隔（默认 10 秒）领取任务。网络错误按 10、20、40、60 秒退避，成功后恢复正常周期。领取到任务后先回传 `received`，下载文件到缓存，核对 SHA-256、验证文件类型和打印机，再交给现有 `AppState`。

### AppState 连接点

`AppState` 继续拥有显示任务及确认/静默状态流转。协调器观察或由 UI 调用其事件入口，在以下节点上回传：领取后 `received`、确认等待 `awaiting_confirmation`、提交系统打印时 `printing`、成功 `succeeded`、取消 `cancelled`、失败 `failed`。本地文件任务不调用远程 API。

## 任务流

1. 用户在设置页保存 API 地址、设备名、注册码并选择连接；客户端注册或恢复凭证。
2. 客户端立即同步打印机列表，之后每 5 分钟以及检测到列表改变时同步。
3. 客户端轮询领取最多 5 个任务；平台负责原子锁定，避免重复领取。
4. 每个任务按签名 HTTPS URL 下载到缓存，验证文件扩展名、SHA-256 和 `printerName`。
5. 验证通过的任务显示在现有任务列表，支持预览、确认或静默提交；失败任务显示原因并回传规范错误码。
6. 系统打印完成后，回传最终状态并删除对应缓存文件；失败或取消也删除文件。

## 错误与安全规则

- `DOWNLOAD_FAILED` 为可重试错误；`CHECKSUM_MISMATCH`、`UNSUPPORTED_FILE`、`PRINTER_NOT_FOUND` 为不可重试。
- 系统打印错误回传 `PRINT_FAILED`；用户取消回传 `USER_CANCELLED`。
- 拒绝 HTTP、文件重定向到 HTTP、超过合理文件大小和不匹配的扩展名。
- 无有效 API 配置时不启动远程轮询，仍允许本地文件打印。
- 默认不自动重试已提交系统打印的任务，避免重复出纸。

## 测试与验收

1. 纯 API 模型、SHA-256、文件类型和退避调度具有 Swift XCTest 覆盖。
2. 使用 URLProtocol 假服务验证注册、领取、下载与事件序列，不调用真实平台。
3. 以本地模拟 HTTP 服务验证设置、预览、确认模式、静默模式及失败提示。
4. 真正的平台联调只需提供 HTTPS 基础地址和一个测试注册码；可先使用 macOS 的“存储为 PDF”验证系统打印。

## 非目标

- Windows 客户端不在本次范围内。
- 不实现平台服务端、订单系统或用户账号管理。
- 不支持云端直接连接或控制本机打印机。
