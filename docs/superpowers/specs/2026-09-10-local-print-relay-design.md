# 本地远程打印测试中转站设计

## 目标

提供一个仅监听本机的 HTTP 服务，使本地业务软件能上传 PDF/图片并创建打印任务；服务同时实现 macOS 远程打印客户端所使用的 API v1，从而在没有真实云端的情况下验证完整链路。

## 拓扑

```text
业务软件 → POST 127.0.0.1:17880/sender/jobs → 本地测试中转站
                                                ├─ 文件缓存
                                                ├─ 任务队列
                                                └─ API v1
                                                     ↓
                                           macOS 远程打印控制台
```

## 范围

- 新建 `outputs/RemotePrintRelay` Node.js 服务，使用 Express、Multer 和 Node 内置 `crypto`。
- 只绑定 `127.0.0.1`，固定端口 `17880`；拒绝非本机监听地址。
- 仅用于开发测试：任务与文件存于服务目录的 `data/`，重启后保留；无用户体系、无公网认证。
- 发送端接受 PDF/JPG/JPEG/PNG，单文件限制 25 MB，计算 SHA-256。
- macOS 客户端仅对 `http://127.0.0.1:17880` 放行 HTTP；其他地址仍强制 HTTPS。

## 发送端 HTTP API

### 创建任务

`POST /sender/jobs`，`multipart/form-data`

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `file` | 是 | PDF/JPG/JPEG/PNG 文件 |
| `deviceId` | 是 | macOS 客户端注册后返回的设备编号 |
| `printerName` | 是 | 与客户端同步的打印机名称精确一致 |
| `copies` | 否 | 正整数，默认 1 |

成功返回 `201`：

```json
{ "taskId": "print_xxx", "status": "queued" }
```

失败返回 JSON `{ "error": { "code": "...", "message": "..." } }`，包括 `INVALID_FILE`、`DEVICE_NOT_FOUND`、`PRINTER_NOT_FOUND`。

### 查询任务

`GET /sender/jobs/:taskId` 返回状态与事件列表，供本地业务软件轮询。

## 客户端兼容 API

服务实现现有 API v1：

- `POST /v1/devices/register`：用任意非空注册码创建/恢复测试设备，返回固定期令牌。
- `PUT /v1/devices/:deviceId/printers`：保存设备打印机列表。
- `POST /v1/devices/:deviceId/print-jobs:claim`：原子领取该设备尚未领取的任务。
- `GET /files/:taskId/:fileName`：仅返回对应已领取任务的文件。
- `POST /v1/devices/:deviceId/print-jobs/:taskId/events`：追加状态事件并更新任务状态。

领取响应提供本机 HTTP 文件 URL；客户端仅在 `127.0.0.1` 时接受该 URL。真实 API 仍使用 HTTPS 签名 URL。

## 数据与状态

- `devices.json`：设备、测试令牌与同步打印机。
- `jobs.json`：任务、文件元数据、领取设备、事件和最终状态。
- `files/`：上传后的原始文件，以任务 ID 隔离。
- 任务只能由指定的 `deviceId` 领取一次；已打印、失败或取消任务不再返回。

## 验收

1. `npm test` 覆盖上传验证、设备注册、打印机匹配、领取唯一性和状态事件。
2. `curl` 上传一份 PDF 或图片后返回任务 ID。
3. macOS App 配置 `http://127.0.0.1:17880/v1` 和任意测试注册码，重启后完成注册与打印机同步。
4. 发送端任务被客户端领取，且在确认/静默打印后 `GET /sender/jobs/:taskId` 可看到状态事件。

## 非目标

- 不替代生产云端，不开放局域网或公网访问。
- 不实现正式身份认证、订单系统、批量任务或 Windows 客户端。
