# Windows Remote Print Client Design

## Goal

构建一个最低支持 Windows 10 22H2 的 Windows 原生远程打印客户端，与 macOS 版本共享 Aurora Control 视觉、中文流程和远程 API v1 契约。

## Architecture

- 技术：WPF、.NET 8、MVVM 模式。
- 界面：1440×900 Aurora Control 仪表盘，强制浅色主题，深色文字、蓝青极光渐变与玻璃卡片。
- 本地打印：读取 Windows 系统打印队列；任务指定打印机名称；提供确认打印或静默打印。
- 文件：支持 PDF、JPG、JPEG、PNG。所选文件可删除；预览窗口提供缩小、100%、放大和关闭。
- 配置：API 地址、设备名称、注册码、默认打印方式保存到本机应用数据目录；接入真实注册后，令牌保存到 Windows Credential Manager。

## Feature Parity

1. 显示本机打印机，创建本地测试任务。
2. 文件选择、删除、预览、缩放。
3. 任务状态：已接收、等待确认、正在打印、打印完成、失败、已取消。
4. Aurora 大尺寸控制台与深色文字。
5. 接入配置面板。
6. 按 API v1 预留设备注册、同步打印机、领取任务、下载文件和状态回传的模型与接口层。

## Platform Constraints

- 最低 Windows 10 22H2；支持 Windows 11。
- 首版发布目标 `win-x64`；未来可增加 `win-arm64`。
- 当前 macOS 环境无法运行或验证 Windows 可执行文件；将进行项目编译、静态检查和单元测试，最终 Windows 打印验证需要在一台 Windows 10/11 设备执行。

## Acceptance Criteria

- `dotnet build` 与 `dotnet test` 在 Windows 环境通过。
- Windows App 显示 Aurora 仪表盘并显示本机打印机。
- 选择 PDF/图片后能预览、缩放、删除和创建任务。
- 确认模式显示 Windows 系统打印对话框；静默模式提交指定打印机。
- API 数据模型与 [API v1](../../../outputs/RemotePrintSimulator/docs/API_V1.md) 的任务字段一致。
