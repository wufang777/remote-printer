# 远程打印发送端（macOS）

这是用于本地验收的文件发送 App。它手动选择一个 PDF、JPG、JPEG 或 PNG 文件，并把文件提交给本机中转站；中转站随后将任务交给已连接的 macOS 打印客户端。

## 测试环境

- macOS 14 Sonoma 或更高版本
- 完整版 Xcode（用于重新构建）
- Node.js 20 或更高版本
- 已构建并打开的“远程打印模拟器 Local Relay”客户端

## 启动顺序

1. 在 `outputs/RemotePrintRelay` 运行 `npm install`（首次需要）和 `node src/server.js`。
2. 打开“远程打印模拟器 Local Relay.app”，在连接设置填入：
   - API 地址：`http://127.0.0.1:17880/v1`
   - 设备名称：任意清晰名称，例如“办公室 Mac”
   - 注册码：`RP-LOCAL-TEST`
3. 在模拟器内同步本机打印机列表。目标打印机必须显示为在线。
4. 双击 `Remote Print Sender.app`。依次选择打印客户端、目标打印机和一个本地文件，点击“发送到远程打印”。
5. 返回模拟器：任务会显示在列表中；若模拟器设为“打印前确认”，请点击确认打印。发送端可点击“刷新状态”查看任务状态。

## 打包与检查

在本目录运行：

```zsh
zsh Scripts/package_app.sh
```

产物为 `Remote Print Sender.app`。该 App 仅连接 `http://127.0.0.1:17880`，不保存文件或设备凭证。
