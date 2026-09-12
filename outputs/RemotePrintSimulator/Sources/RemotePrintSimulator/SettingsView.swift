import SwiftUI
import RemotePrintCore

struct SettingsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        Form {
            Picker("Task handling", selection: $state.behavior) {
                Text("Confirm before printing").tag(PrintBehavior.confirm)
                Text("Silent printing").tag(PrintBehavior.silent)
            }
            Section("Detected printers") {
                if state.availablePrinters.isEmpty {
                    Text("No local printers detected").foregroundStyle(.secondary)
                } else {
                    ForEach(state.availablePrinters, id: \.self) { Text($0) }
                }
            }
        }
        .padding()
    }
}
