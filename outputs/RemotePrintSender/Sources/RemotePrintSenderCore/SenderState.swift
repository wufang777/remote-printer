import Foundation
import Observation

@MainActor
@Observable
public final class SenderState {
    public var devices: [RelayDevice] = []
    public var printers: [RelayPrinter] = []
    public var selectedDeviceID: String?
    public var selectedPrinterName: String?
    public var fileURL: URL?
    public var task: SenderJob?
    public var message = "正在连接本机中转站…"
    public var isLoading = false

    public var canSend: Bool { fileURL != nil && selectedDeviceID != nil && selectedPrinterName != nil && !isLoading }
    private let client: RelaySenderClient

    public init(client: RelaySenderClient? = nil) {
        self.client = client ?? (try! RelaySenderClient())
    }

    public func loadDevices() async {
        isLoading = true
        defer { isLoading = false }
        do {
            devices = try await client.loadDevices()
            message = devices.isEmpty ? "尚未发现已连接的打印客户端。" : "已发现 \(devices.count) 个打印客户端。"
        } catch { message = error.localizedDescription }
    }

    public func selectDevice(_ deviceID: String?) async {
        selectedDeviceID = deviceID
        selectedPrinterName = nil
        printers = []
        guard let deviceID else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            printers = try await client.loadPrinters(deviceID: deviceID)
            selectedPrinterName = printers.first(where: \.isDefault)?.name ?? printers.first(where: \.isOnline)?.name
            message = printers.isEmpty ? "此客户端尚未同步打印机。" : "请选择目标打印机。"
        } catch { message = error.localizedDescription }
    }

    public func chooseFile(_ url: URL) {
        fileURL = url
        task = nil
        message = "已选择：\(url.lastPathComponent)"
    }

    public func removeFile() {
        fileURL = nil
        task = nil
        message = "请先选择要发送的文件。"
    }

    public func send() async {
        guard let fileURL, let selectedDeviceID, let selectedPrinterName else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            task = try await client.send(fileURL: fileURL, deviceID: selectedDeviceID, printerName: selectedPrinterName)
            message = "任务已提交，正在等待打印客户端接收。"
            await pollTask()
        } catch { message = error.localizedDescription }
    }

    public func pollTask() async {
        guard let task else { return }
        do {
            let latest = try await client.job(taskID: task.taskId)
            self.task = latest
            message = "任务状态：\(latest.status)"
        } catch { message = error.localizedDescription }
    }
}
