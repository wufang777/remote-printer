import AppKit
import PDFKit
import RemotePrintCore

@MainActor
enum LocalFilePrinter {
    struct PrintError: Error {
        let message: String
    }

    static func submit(_ job: PrintJob, showsPrintPanel: Bool) -> Result<Void, PrintError> {
        guard let fileURL = job.fileURL else {
            return .failure(PrintError(message: "未选择本地打印文件。"))
        }
        if job.contentType == .document {
            let raw = UserDefaults.standard.string(forKey: "remotePrint.documentStrategy") ?? DocumentPrintStrategy.defaultValue.rawValue
            let strategy = DocumentPrintStrategy(rawValue: raw) ?? .automatic
            return DocumentPrintService.openForPrinting(fileURL: fileURL, strategy: strategy)
        }
        guard let printer = NSPrinter(name: job.printerName) else {
            return .failure(PrintError(message: "找不到所选打印机。"))
        }

        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.printer = printer
        let operation: NSPrintOperation

        if job.contentType == .pdf, let document = PDFDocument(url: fileURL) {
            let pdfView = PDFView()
            pdfView.document = document
            let pageBounds = document.page(at: 0)?.bounds(for: .mediaBox) ?? NSRect(x: 0, y: 0, width: 595, height: 842)
            pdfView.frame = pageBounds
            operation = NSPrintOperation(view: pdfView, printInfo: printInfo)
        } else if let image = NSImage(contentsOf: fileURL) {
            let imageView = NSImageView(image: image)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.frame = NSRect(origin: .zero, size: image.size)
            operation = NSPrintOperation(view: imageView, printInfo: printInfo)
        } else {
            return .failure(PrintError(message: "仅支持可读取的 PDF 或图片文件。"))
        }

        operation.showsPrintPanel = showsPrintPanel
        operation.showsProgressPanel = showsPrintPanel
        return operation.run() ? .success(()) : .failure(PrintError(message: "打印任务未完成。"))
    }
}
