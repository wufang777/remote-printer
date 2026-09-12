import SwiftUI
import UniformTypeIdentifiers
import RemotePrintSenderCore

struct SenderView: View {
    @State private var state = SenderState()
    @State private var isFileImporterPresented = false

    var body: some View {
        ZStack {
            AuroraTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    HStack(alignment: .top, spacing: 24) {
                        fileCard.frame(maxWidth: .infinity)
                        destinationCard.frame(maxWidth: .infinity)
                    }
                    statusCard
                }
                .padding(42)
            }
        }
        .task { await state.loadDevices() }
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: supportedContentTypes, allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { state.chooseFile(url) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("远程打印发送端", systemImage: "paperplane.circle.fill")
                .font(.system(size: 37, weight: .bold)).foregroundStyle(Color(red: 0.03, green: 0.10, blue: 0.24))
            Text("选择一个文件，发送至已连接的 macOS 打印客户端")
                .font(.title3).foregroundStyle(.black.opacity(0.62))
        }
    }

    private var fileCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 20) {
                Label("1. 选择文件", systemImage: "doc.badge.plus")
                    .font(.title2.weight(.bold)).foregroundStyle(.black)
                if let url = state.fileURL {
                    HStack(spacing: 14) {
                        Image(systemName: icon(for: url)).font(.system(size: 36)).foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text(url.lastPathComponent).font(.headline).foregroundStyle(.black).lineLimit(2)
                            Text("PDF、图片、Office 或 WPS 文档，最大 25 MB").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("删除", role: .destructive) { state.removeFile() }
                    }
                    .padding(16).background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                } else {
                    Text("支持 PDF、图片、Office（Word/Excel/PowerPoint）及 WPS 文档，单文件最大 25 MB。文件只会交给本机中转站，不会被本应用保存。")
                        .foregroundStyle(.black.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
                }
                Button { isFileImporterPresented = true } label: {
                    Label(state.fileURL == nil ? "选择本地文件" : "更换文件", systemImage: "folder")
                        .frame(maxWidth: .infinity).frame(height: 52)
                }
                .buttonStyle(.borderedProminent).tint(.blue)
            }
        }
    }

    private var destinationCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 20) {
                Label("2. 设置目标", systemImage: "printer.fill")
                    .font(.title2.weight(.bold)).foregroundStyle(.black)
                Picker("打印客户端", selection: Binding(get: { state.selectedDeviceID ?? "" }, set: { value in Task { await state.selectDevice(value.isEmpty ? nil : value) } })) {
                    Text("请选择打印客户端").tag("")
                    ForEach(state.devices) { device in
                        Text(device.deviceName).tag(device.deviceId)
                    }
                }.pickerStyle(.menu)
                Picker("目标打印机", selection: Binding(get: { state.selectedPrinterName ?? "" }, set: { state.selectedPrinterName = $0.isEmpty ? nil : $0 })) {
                    Text("请选择打印机").tag("")
                    ForEach(state.printers.filter(\.isOnline)) { printer in Text(printer.name + (printer.isDefault ? "（默认）" : "")).tag(printer.name) }
                }.pickerStyle(.menu).disabled(state.selectedDeviceID == nil)
                Button { Task { await state.send() } } label: {
                    Label(state.isLoading ? "正在发送…" : "发送到远程打印", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity).frame(height: 56)
                }
                .buttonStyle(.borderedProminent).tint(.indigo).disabled(!state.canSend)
            }
        }
    }

    private var statusCard: some View {
        GlassCard {
            HStack(spacing: 16) {
                Image(systemName: state.task == nil ? "dot.radiowaves.left.and.right" : "checkmark.seal.fill")
                    .font(.system(size: 28)).foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("本机中转状态").font(.headline).foregroundStyle(.black)
                    Text(state.message).foregroundStyle(.black.opacity(0.68))
                    if let task = state.task { Text("任务编号：\(task.taskId)").font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                if state.task != nil { Button("刷新状态") { Task { await state.pollTask() } }.buttonStyle(.bordered) }
            }
        }
    }

    private var supportedContentTypes: [UTType] {
        [.pdf, .jpeg, .png] + ["doc", "docx", "xls", "xlsx", "ppt", "pptx", "csv", "wps", "et", "dps"].compactMap { UTType(filenameExtension: $0) }
    }

    private func icon(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "csv", "wps", "et", "dps": return "doc.richtext"
        default: return "photo"
        }
    }
}
