import SwiftUI
import RemotePrintCore

struct ConnectionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var state: AppState
    @AppStorage("remotePrint.apiBaseURL") private var savedAPIBaseURL = ""
    @AppStorage("remotePrint.deviceName") private var savedDeviceName = Host.current().localizedName ?? "我的 Mac"
    @AppStorage("remotePrint.activationCode") private var savedActivationCode = ""
    @AppStorage("remotePrint.behavior") private var savedBehavior = PrintBehavior.confirm.rawValue

    @State private var apiBaseURL = ""
    @State private var deviceName = ""
    @State private var activationCode = ""
    @State private var behavior = PrintBehavior.confirm
    @State private var validationMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("接入配置")
                .font(.title2.bold())
            Text("保存后，客户端会使用这些信息连接远程打印平台。")
                .foregroundStyle(.secondary)

            Form {
                TextField("API 地址", text: $apiBaseURL, prompt: Text("https://api.example.com/v1"))
                TextField("设备名称", text: $deviceName, prompt: Text("例如：上海门店 Mac mini"))
                TextField("注册码", text: $activationCode, prompt: Text("例如：RP-8F2K-91MZ"))
                Picker("默认打印方式", selection: $behavior) {
                    Text("打印前确认").tag(PrintBehavior.confirm)
                    Text("静默打印").tag(PrintBehavior.silent)
                }
            }
            .formStyle(.grouped)

            if let validationMessage {
                Text(validationMessage).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存配置") { save() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 520)
        .onAppear {
            apiBaseURL = savedAPIBaseURL
            deviceName = savedDeviceName
            activationCode = savedActivationCode
            behavior = PrintBehavior(rawValue: savedBehavior) ?? .confirm
        }
    }

    private func save() {
        let configuration = ConnectionConfiguration(
            apiBaseURL: apiBaseURL,
            deviceName: deviceName,
            activationCode: activationCode
        )
        guard let error = configuration.validationError else {
            savedAPIBaseURL = configuration.apiBaseURL
            savedDeviceName = configuration.deviceName
            savedActivationCode = configuration.activationCode
            savedBehavior = behavior.rawValue
            state.behavior = behavior
            dismiss()
            return
        }
        validationMessage = error
    }
}
