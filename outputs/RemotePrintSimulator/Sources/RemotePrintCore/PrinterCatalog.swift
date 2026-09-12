import AppKit

public protocol PrinterCatalog {
    func printerNames() -> [String]
}

public struct SystemPrinterCatalog: PrinterCatalog {
    public init() {}

    public func printerNames() -> [String] {
        NSPrinter.printerNames.sorted()
    }
}
