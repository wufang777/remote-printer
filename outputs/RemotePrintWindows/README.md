# Windows 远程打印客户端（Aurora Control）

这是与 macOS 版本一致的 Windows 本地打印客户端源码。第一版用于先测通本地文件打印；接入平台时沿用 macOS 端的 API v1 契约。

## 支持范围

- 最低系统：**Windows 10 22H2（x64）**，建议 Windows 11。
- 文件：PDF、JPG、JPEG、PNG。
- 工作流：选择本地文件 → 选择 Windows 打印机 → 打印前确认或静默提交 → 查看任务状态。
- 配置：API 地址、设备名称、注册码、默认打印模式；保存位置为 `%LocalAppData%\\RemotePrintWindows\\settings.json`。

## Windows 测试环境

在 Windows 电脑上准备以下环境：

1. Windows 10 22H2 x64 或更高版本，并已完成 Windows Update。
2. 已连接或已添加至少一台打印机。若暂时没有实体设备，可使用 **Microsoft Print to PDF** 做流程测试。
3. 已安装 [.NET 8 SDK x64](https://dotnet.microsoft.com/download/dotnet/8.0)，在 PowerShell 执行 `dotnet --info` 应能显示 8.x SDK。
4. 测试 PDF 预览或 PDF 静默打印时，安装并设置可处理 PDF 的默认应用：Windows 自带 Microsoft Edge 即可；Adobe Acrobat Reader 也可。
5. 允许应用访问本地文件与 Windows 打印队列。无需管理员权限；只有安装打印机驱动时可能需要管理员权限。

> 图片静默打印使用 Windows 原生打印队列。PDF 静默打印通过 Windows 默认 PDF 应用的 `printto` 动作发往任务指定的打印机；请先用该默认应用手工打印一份 PDF，确认驱动和队列正常。

## 构建与启动

将整个 `RemotePrintWindows` 文件夹复制到 Windows，例如 `C:\\RemotePrintWindows`，在 PowerShell 运行：

```powershell
cd C:\RemotePrintWindows
dotnet restore
dotnet build -c Release
dotnet run --project .\RemotePrintWindows.csproj
```

如果只想用 Visual Studio：安装 **Visual Studio 2022 Community**，选择“使用 .NET 的桌面开发”工作负载，然后打开 `RemotePrintWindows.csproj`，按 `F5` 启动。

## 本地打印验收步骤

1. 启动后确认“目标打印机”下拉框能看到 **Microsoft Print to PDF** 或实体打印机。
2. 点击“选择本地文件”，选一份 JPG/PNG，点击“预览”，用 `−` / `+` 验证缩放；点击“关闭”回到主界面。
3. 选择目标打印机并保持“打印前确认”，点击“发送打印任务”；新任务应显示“等待确认”。
4. 在任务卡点击“确认打印”。任务状态依次显示“正在打印”“打印已提交”；检查打印机输出或 Microsoft Print to PDF 的保存对话框。
5. 选择“静默打印”，重新创建一份图片任务，验证任务无需确认即进入“打印已提交”。
6. 用 PDF 重复步骤 2–5：预览点击“打开 PDF 预览”后，应由系统默认 PDF 应用打开；打印前先确认该应用可以向指定打印机输出。
7. 点击“接入配置”，填写测试 API 地址、设备名称和注册码并保存；关闭重启后再次打开配置，确认值仍在。

## 自动化检查

在 Windows PowerShell 运行：

```powershell
dotnet test .\Tests\RemotePrintWindows.Tests.csproj
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:PublishTrimmed=false
```

发布产物在 `bin\\Release\\net8.0-windows10.0.19045.0\\win-x64\\publish`。将整个 `publish` 目录复制给测试人员，双击 `RemotePrintWindows.exe` 启动。

## 平台 API 接入

Windows 端预留的接入字段和任务模型与 macOS 端保持一致。完整请求、响应和回传状态定义见：

[`../RemotePrintSimulator/docs/API_V1.md`](../RemotePrintSimulator/docs/API_V1.md)

接入真实平台前，应依次完成设备注册、令牌获取、打印机列表同步、任务领取、文件下载/校验、任务状态回传。第一版 Windows 本地客户端目前先完成本地打印流程，远程轮询/下载将在本地验收通过后按此 API 文档接入。
