import SwiftUI
import UniformTypeIdentifiers
import RemotePrintCore

private enum ActiveSheet: Identifiable {
    case connectionSettings
    case preview(URL)

    var id: String {
        switch self {
        case .connectionSettings: "connection-settings"
        case let .preview(url): "preview-\(url.path)"
        }
    }
}

struct SimulatorView: View {
    @ObservedObject var state: AppState
    @State private var contentType: PrintContentType = .pdf
    @State private var printerName = ""
    @State private var fileURL: URL?
    @State private var isSelectingFile = false
    @State private var activeSheet: ActiveSheet?
    @State private var previewZoom = PreviewZoom()
    @AppStorage("remotePrint.documentStrategy") private var documentStrategy = DocumentPrintStrategy.defaultValue.rawValue
    @AppStorage("remotePrint.pollIntervalSeconds") private var pollIntervalSeconds = 1

    var body: some View {
        ZStack {
            auroraBackground
            ScrollView {
                VStack(spacing: 26) {
                    header
                    dashboard
                    taskPanel
                }
                .padding(32)
            }
        }
        .frame(minWidth: 1120, minHeight: 760)
        .onAppear { if printerName.isEmpty { printerName = state.availablePrinters.first ?? "" } }
        .fileImporter(isPresented: $isSelectingFile, allowedContentTypes: [.pdf, .image] + ["doc", "docx", "xls", "xlsx", "ppt", "pptx", "wps", "et", "dps"].compactMap { UTType(filenameExtension: $0) }, allowsMultipleSelection: false) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            fileURL = url
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .connectionSettings:
                ConnectionSettingsView(state: state)
            case let .preview(url):
                previewSheet(url)
            }
        }
    }

    private var auroraBackground: some View {
        LinearGradient(colors: [Color(red: 0.96, green: 0.98, blue: 1), Color(red: 0.91, green: 0.96, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(alignment: .topTrailing) {
                Circle().fill(AuroraTheme.primaryGradient.opacity(0.22)).frame(width: 520, height: 520).blur(radius: 52).offset(x: 120, y: -180)
            }
    }

    private var header: some View {
        HStack(spacing: 16) {
            ZStack { RoundedRectangle(cornerRadius: 16).fill(AuroraTheme.primaryGradient); Image(systemName: "printer.fill").font(.title2.weight(.bold)).foregroundStyle(Color(red: 0.03, green: 0.10, blue: 0.24)) }
                .frame(width: 54, height: 54).shadow(color: .blue.opacity(0.28), radius: 12, y: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text("远程打印控制台").font(.system(size: 28, weight: .bold))
                Text("本机设备 · 实时任务通道").font(.system(size: 15)).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) { Circle().fill(.green).frame(width: 9, height: 9).shadow(color: .green.opacity(0.7), radius: 6); Text("系统在线") }
                .font(.headline).padding(.horizontal, 16).frame(minHeight: 44).background(.green.opacity(0.10), in: Capsule()).foregroundStyle(Color.green.opacity(0.85))
            Button { activeSheet = .connectionSettings } label: { Image(systemName: "gearshape.fill").font(.title3).frame(width: 44, height: 44) }
                .buttonStyle(.bordered).help("接入配置")
        }
    }

    private var dashboard: some View {
        HStack(alignment: .top, spacing: 22) {
            AuroraGlassCard { createTaskCard }.frame(maxWidth: .infinity)
            VStack(spacing: 22) { deviceCard; metricsCard }.frame(width: 340)
        }
    }

    private var createTaskCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { VStack(alignment: .leading, spacing: 5) { Text("创建打印任务").font(.system(size: 22, weight: .bold)); Text("选择文件和目标设备，安全下发本地打印。").foregroundStyle(.secondary) }; Spacer(); Image(systemName: "paperplane.fill").font(.title2).foregroundStyle(.blue) }
            HStack(spacing: 16) {
                Picker("内容类型", selection: $contentType) { ForEach(PrintContentType.allCases, id: \.self) { Text(title(for: $0)).tag($0) } }.frame(maxWidth: .infinity)
                Picker("目标打印机", selection: $printerName) { Text("请选择打印机").tag(""); ForEach(state.availablePrinters, id: \.self) { Text($0).tag($0) } }.frame(maxWidth: .infinity)
            }
            Picker("处理方式", selection: $state.behavior) { Text("打印前确认").tag(PrintBehavior.confirm); Text("静默打印").tag(PrintBehavior.silent) }.pickerStyle(.segmented)
            Picker("Office / WPS 打印策略", selection: $documentStrategy) {
                Text("自动选择（默认）").tag(DocumentPrintStrategy.automatic.rawValue)
                Text("本机 Office / WPS 打开打印").tag(DocumentPrintStrategy.nativeApplication.rawValue)
                Text("转换为 PDF 后打印").tag(DocumentPrintStrategy.convertToPDF.rawValue)
            }
            Stepper("任务轮询间隔：\(pollIntervalSeconds) 秒", value: $pollIntervalSeconds, in: 1...60)
            HStack(spacing: 12) {
                Button("选择本地文件", systemImage: "folder.badge.plus") { isSelectingFile = true }.buttonStyle(.bordered).controlSize(.large)
                Text(fileURL?.lastPathComponent ?? "尚未选择 PDF 或图片文件").lineLimit(1).foregroundStyle(fileURL == nil ? .secondary : .primary).frame(maxWidth: .infinity, alignment: .leading)
                Button("预览", systemImage: "eye") { openPreview(fileURL) }.buttonStyle(.bordered).controlSize(.large).disabled(fileURL == nil)
                Button("删除", systemImage: "trash") { fileURL = nil }.buttonStyle(.bordered).controlSize(.large).disabled(fileURL == nil)
            }
            Button("发送打印任务", systemImage: "bolt.fill") { sendTask() }.buttonStyle(AuroraPrimaryButtonStyle()).disabled(printerName.isEmpty || fileURL == nil)
        }
    }

    private var deviceCard: some View {
        AuroraGlassCard { VStack(alignment: .leading, spacing: 15) { Label("设备状态", systemImage: "dot.radiowaves.left.and.right").font(.headline); Text(printerName.isEmpty ? "未选择设备" : printerName).font(.title3.weight(.bold)); HStack { Circle().fill(.green).frame(width: 9, height: 9); Text("已连接 · 低延迟") }.foregroundStyle(.green).font(.subheadline) } }
    }

    private var metricsCard: some View {
        AuroraGlassCard { VStack(alignment: .leading, spacing: 8) { Text("今日任务").font(.headline); Text("\(state.jobs.count)").font(.system(size: 44, weight: .bold)).foregroundStyle(AuroraTheme.primaryGradient); Text("已进入本机任务通道").foregroundStyle(.secondary) } }
    }

    private var taskPanel: some View {
        AuroraGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack { VStack(alignment: .leading, spacing: 3) { Text("最近任务").font(.system(size: 22, weight: .bold)); Text("文件预览、状态追踪与打印操作").foregroundStyle(.secondary) }; Spacer(); Text("\(state.jobs.count) 项").font(.headline).foregroundStyle(.blue) }
                if state.jobs.isEmpty { ContentUnavailableView("暂无打印任务", systemImage: "tray", description: Text("请选择打印机和文件后创建第一条任务。")) .frame(maxWidth: .infinity).padding(.vertical, 36) }
                else { LazyVStack(spacing: 10) { ForEach(state.jobs) { taskRow($0) } } }
            }
        }
    }

    private func taskRow(_ job: PrintJob) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon(for: job.status)).font(.title3).foregroundStyle(AuroraTheme.statusColor(job.status)).frame(width: 40, height: 40).background(AuroraTheme.statusColor(job.status).opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 4) { Text(job.fileURL?.lastPathComponent ?? title(for: job.contentType)).font(.headline); Text("\(title(for: job.contentType)) · \(job.printerName)").foregroundStyle(.secondary); Text(job.failureReason ?? title(for: job.status)).font(.subheadline).foregroundStyle(AuroraTheme.statusColor(job.status)) }
            Spacer()
            if let url = job.fileURL { Button("预览") { openPreview(url) }.buttonStyle(.bordered).controlSize(.large) }
            if job.status == .awaitingConfirmation { Button("确认") { if let printable = state.approve(jobID: job.id) { submit(printable, showsPrintPanel: true) } }.buttonStyle(.borderedProminent).controlSize(.large); Button("取消", role: .destructive) { state.cancel(jobID: job.id) }.buttonStyle(.bordered).controlSize(.large) }
        }
        .padding(16).frame(minHeight: 76).background(.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func previewSheet(_ url: URL) -> some View {
        VStack(spacing: 0) { HStack { Text(url.lastPathComponent).font(.headline); Spacer(); Button("−") { previewZoom.zoomOut() }; Button("\(Int(previewZoom.scale * 100))%") { previewZoom.reset() }; Button("+") { previewZoom.zoomIn() }; Button("关闭") { activeSheet = nil } }.buttonStyle(.bordered).controlSize(.large).padding(18); Divider(); PrintPreviewView(fileURL: url, zoomScale: previewZoom.scale) }.frame(minWidth: 880, minHeight: 680)
    }

    private func sendTask() { let job = PrintJob(contentType: contentType, printerName: printerName, fileURL: fileURL); if let printable = state.receive(job) { submit(printable, showsPrintPanel: false) } }
    private func openPreview(_ url: URL?) { guard let url else { return }; previewZoom.reset(); activeSheet = .preview(url) }
    private func submit(_ job: PrintJob, showsPrintPanel: Bool) { switch LocalFilePrinter.submit(job, showsPrintPanel: showsPrintPanel) { case .success: state.complete(jobID: job.id); case let .failure(error): state.fail(jobID: job.id, reason: error.message) } }
    private func icon(for status: PrintJobStatus) -> String { switch status { case .received, .awaitingConfirmation: "clock.fill"; case .printing: "printer.fill"; case .succeeded: "checkmark.circle.fill"; case .failed: "exclamationmark.triangle.fill"; case .cancelled: "xmark.circle.fill" } }
    private func title(for type: PrintContentType) -> String { switch type { case .pdf: "PDF 文档"; case .image: "图片"; case .document: "Office / WPS 文档"; case .label: "标签"; case .receipt: "票据" } }
    private func title(for status: PrintJobStatus) -> String { switch status { case .received: "已接收"; case .awaitingConfirmation: "等待确认"; case .printing: "正在打印"; case .succeeded: "打印完成"; case .failed: "打印失败"; case .cancelled: "已取消" } }
}
