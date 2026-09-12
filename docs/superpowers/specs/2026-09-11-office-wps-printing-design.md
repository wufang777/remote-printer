# Office 与 WPS 打印格式设计

## 目标

让本地发送端、中转站和 macOS 远程打印控制台共同支持 Office 与 WPS 文件；任务仍须先进入控制台，用户确认后才开始打印。

## 支持格式

保留现有 `pdf`、`jpg`、`jpeg`、`png`，新增 Office：`doc`、`docx`、`xls`、`xlsx`、`ppt`、`pptx`；新增 WPS：`wps`、`et`、`dps`。单文件大小上限继续为 25 MB。

## 数据流

发送端按后缀选择 MIME 类型并上传文件。中转站使用同一份格式清单验证上传，并将任务标记为 `pdf`、`image`、`office` 或 `wps`。控制台领取任务、校验后缀和 SHA-256 后缓存文件，展示为“Office 文档”或“WPS 文档”，并保持 `awaiting_confirmation` 状态。

## 打印处理设置

新增 `DocumentPrintStrategy`，在 macOS 控制台设置界面中选择并持久化：

- `nativeApplication`（本机应用直印）：确认后使用匹配的已安装应用打开文件并交给 macOS 打印对话框。Office 文件优先使用 Microsoft Word、Excel 或 PowerPoint；WPS 文件使用 WPS Office。
- `convertToPDF`（转换为 PDF 后打印）：确认后使用本机转换器产出临时 PDF，再沿用当前 PDF 打印流程；转换器不可用时任务失败并显示明确原因。
- `automatic`（自动选择，默认）：先尝试转换为 PDF；转换器不可用或转换失败时回退至本机应用直印。

转换器使用可执行的 `soffice` 或 `libreoffice` 命令；未安装 LibreOffice 时不隐式安装软件。转换和打开均在用户点击确认之后触发。临时 PDF 只保存在应用缓存目录。

## 预览与错误

PDF、图片继续提供内嵌缩放预览。Office/WPS 文档的“预览”按钮使用系统 Quick Look；如系统无法渲染，按钮提供“用本机应用打开”。用户确认后若找不到所需应用、转换器或打印机，任务将显示失败原因并向中转站回传 `PRINT_FAILED`。

## 验收

1. 发送端可选择并上传每一个新增格式。
2. 中转站拒绝未知后缀，接受新增后缀，并返回正确内容类型。
3. 控制台能领取、校验并列出 Office/WPS 任务，状态先为“等待确认”。
4. 设置可切换三种策略，默认“自动选择”。
5. 自动策略在未安装 LibreOffice 时回退至匹配本机应用，而不会静默丢失任务。
