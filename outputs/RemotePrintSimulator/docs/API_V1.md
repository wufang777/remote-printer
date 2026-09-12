# 远程打印平台 API v1

## 目标

macOS 客户端主动连接平台，注册设备、同步可用打印机、领取任务、下载文件，并回传打印状态。客户端不开放公网端口。

## 基础约定

- 基础地址：`https://api.example.com/v1`
- 所有请求和响应均为 `application/json`，文件下载接口除外。
- 客户端认证：`Authorization: Bearer <deviceAccessToken>`。
- 时间使用 ISO 8601 UTC，例如 `2026-08-16T07:00:00Z`。
- `deviceId` 是客户端首次注册后平台返回的稳定设备编号。
- `printerName` 必须精确匹配客户端同步上来的本机打印机名称。
- 客户端每 10 秒拉取一次任务；网络错误时按 10、20、40、60 秒退避重试。

## 1. 注册设备

`POST /devices/register`

客户端首次启动或令牌失效时调用。注册码由平台后台生成并给用户。

请求：

```json
{
  "activationCode": "RP-8F2K-91MZ",
  "deviceName": "上海门店 Mac mini",
  "platform": "macOS",
  "appVersion": "0.2.0",
  "osVersion": "14.6"
}
```

成功响应：

```json
{
  "deviceId": "dev_01JABCDEF123456789",
  "accessToken": "eyJhbGciOi...",
  "expiresAt": "2026-11-14T07:00:00Z",
  "pollIntervalSeconds": 10
}
```

客户端将 `deviceId` 和 `accessToken` 存入 macOS Keychain，不写入日志或普通配置文件。

## 2. 同步打印机

`PUT /devices/{deviceId}/printers`

客户端启动后、每 5 分钟一次、以及检测到打印机变化时调用。

请求：

```json
{
  "printers": [
    {
      "name": "192.168.0.17",
      "isDefault": true,
      "isOnline": true
    },
    {
      "name": "Receipt Printer",
      "isDefault": false,
      "isOnline": true
    }
  ]
}
```

成功响应：`204 No Content`

## 3. 领取打印任务

`POST /devices/{deviceId}/print-jobs:claim`

客户端按轮询间隔调用。服务端应原子地将返回的任务锁定给该设备，避免重复打印。

请求：

```json
{
  "maxJobs": 5,
  "supportedFormats": ["pdf", "image"],
  "availablePrinters": ["192.168.0.17", "Receipt Printer"]
}
```

成功响应：

```json
{
  "jobs": [
    {
      "taskId": "print_01JABCDE123",
      "printerName": "192.168.0.17",
      "contentType": "pdf",
      "file": {
        "downloadUrl": "https://files.example.com/signed/print_01JABCDE123.pdf",
        "sha256": "a1b2c3d4...",
        "fileName": "order-20260816.pdf",
        "expiresAt": "2026-08-16T07:10:00Z"
      },
      "printOptions": {
        "copies": 1,
        "duplex": "none",
        "paperSize": "A4"
      },
      "requestedAt": "2026-08-16T07:00:00Z"
    }
  ]
}
```

无任务时返回：

```json
{ "jobs": [] }
```

字段限制：

- `contentType`：第一阶段仅接受 `pdf` 和 `image`。标签、票据应由平台预生成 PDF。
- `downloadUrl`：一次性 HTTPS 签名 URL，建议至少 10 分钟有效；客户端不额外附带 Bearer Token。
- `sha256`：文件完整性校验，64 位小写十六进制。
- `printerName`：若客户端不包含该打印机，客户端回传 `failed`，错误码为 `PRINTER_NOT_FOUND`。

## 4. 下载文件

客户端对 `file.downloadUrl` 发起 `GET`，写入应用缓存目录，校验 SHA-256 成功后才能打印。下载 URL 不使用本 API 的 JSON 包装，也不应重定向到 HTTP。

## 5. 回传状态

`POST /devices/{deviceId}/print-jobs/{taskId}/events`

请求：

```json
{
  "status": "printing",
  "occurredAt": "2026-08-16T07:00:12Z"
}
```

状态枚举及使用时机：

| status | 客户端行为 |
| --- | --- |
| `received` | 已从平台成功领取任务。 |
| `awaiting_confirmation` | 已下载且等待本机用户确认。 |
| `printing` | 已提交 macOS 打印系统。 |
| `succeeded` | macOS 打印操作完成。 |
| `failed` | 下载、校验、打印机匹配或打印失败。 |
| `cancelled` | 本机用户取消。 |

失败时额外发送：

```json
{
  "status": "failed",
  "error": {
    "code": "PRINTER_NOT_FOUND",
    "message": "所选打印机不可用。",
    "retryable": false
  },
  "occurredAt": "2026-08-16T07:00:12Z"
}
```

错误码：

- `DOWNLOAD_FAILED`：文件下载失败，可重试。
- `CHECKSUM_MISMATCH`：下载文件校验失败，可重新领取。
- `UNSUPPORTED_FILE`：不是受支持的 PDF 或图片，不重试。
- `PRINTER_NOT_FOUND`：目标打印机不在本机，不重试。
- `PRINT_FAILED`：系统打印失败，由平台决定是否创建新任务重试。
- `USER_CANCELLED`：用户取消，不重试。

## 6. 确认模式

打印行为由客户端本地设置决定，不由平台强制。若客户端设置为“打印前确认”，任务领取后状态为 `awaiting_confirmation`，用户确认时发送 `printing`。若用户 10 分钟未操作，客户端回传 `cancelled` 和 `USER_CANCELLED`。

## 平台需要实现的最小接口

后端第一阶段只需要实现以下四个端点：

1. `POST /devices/register`
2. `PUT /devices/{deviceId}/printers`
3. `POST /devices/{deviceId}/print-jobs:claim`
4. `POST /devices/{deviceId}/print-jobs/{taskId}/events`

客户端接入时还需要平台提供：生产或测试环境的基础地址、一个可用注册码，以及 HTTPS 文件下载地址。
