import AppKit
import SwiftUI
import RemotePrintCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var state: AppState?
    private var coordinator: RemotePrintCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = AppState(printerCatalog: SystemPrinterCatalog())
        state.behavior = PrintBehavior(rawValue: UserDefaults.standard.string(forKey: "remotePrint.behavior") ?? "") ?? .confirm
        let contentView = NSHostingView(rootView: SimulatorView(state: state).preferredColorScheme(.light))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "远程打印模拟器"
        window.appearance = NSAppearance(named: .aqua)
        window.center()
        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.state = state
        let coordinator = RemotePrintCoordinator()
        let configuration = ConnectionConfiguration(
            apiBaseURL: UserDefaults.standard.string(forKey: "remotePrint.apiBaseURL") ?? "",
            deviceName: UserDefaults.standard.string(forKey: "remotePrint.deviceName") ?? "",
            activationCode: UserDefaults.standard.string(forKey: "remotePrint.activationCode") ?? ""
        )
        coordinator.start(configuration: configuration, state: state)
        self.coordinator = coordinator
        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }
}

let application = NSApplication.shared
application.setActivationPolicy(.regular)
let delegate = AppDelegate()
application.delegate = delegate
application.run()
