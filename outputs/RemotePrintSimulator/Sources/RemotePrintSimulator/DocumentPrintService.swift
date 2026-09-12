import AppKit
import RemotePrintCore

@MainActor
enum DocumentPrintService {
    static func openForPrinting(fileURL: URL, strategy: DocumentPrintStrategy) -> Result<Void, LocalFilePrinter.PrintError> {
        let extensionName = fileURL.pathExtension.lowercased()
        let applications: [URL]
        if ["wps", "et", "dps"].contains(extensionName) {
            applications = [URL(fileURLWithPath: "/Applications/wpsoffice.app")]
        } else {
            applications = officeApplications(for: extensionName)
        }
        guard let application = applications.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            return .failure(.init(message: "未找到可打开此文档的本机 Office 或 WPS 应用。"))
        }
        NSWorkspace.shared.open([fileURL], withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration())
        return .success(())
    }

    private static func officeApplications(for extensionName: String) -> [URL] {
        switch extensionName {
        case "doc", "docx": [URL(fileURLWithPath: "/Applications/Microsoft Word.app"), URL(fileURLWithPath: "/Applications/wpsoffice.app")]
        case "xls", "xlsx": [URL(fileURLWithPath: "/Applications/Microsoft Excel.app"), URL(fileURLWithPath: "/Applications/wpsoffice.app")]
        case "csv": [URL(fileURLWithPath: "/Applications/Microsoft Excel.app"), URL(fileURLWithPath: "/Applications/wpsoffice.app")]
        case "ppt", "pptx": [URL(fileURLWithPath: "/Applications/Microsoft PowerPoint.app"), URL(fileURLWithPath: "/Applications/wpsoffice.app")]
        default: []
        }
    }
}
