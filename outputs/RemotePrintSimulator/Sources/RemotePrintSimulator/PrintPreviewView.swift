import AppKit
import PDFKit
import SwiftUI

struct PrintPreviewView: NSViewRepresentable {
    let fileURL: URL
    let zoomScale: Double

    func makeNSView(context: Context) -> PreviewHostView {
        PreviewHostView(fileURL: fileURL)
    }

    func updateNSView(_ view: PreviewHostView, context: Context) {
        view.setZoom(zoomScale)
    }
}

final class PreviewHostView: NSView {
    private let pdfView: PDFView?
    private let imageScrollView: NSScrollView?

    init(fileURL: URL) {
        if let document = PDFDocument(url: fileURL) {
            let view = PDFView()
            view.document = document
            view.autoScales = false
            view.minScaleFactor = 0.25
            view.maxScaleFactor = 4
            view.scaleFactor = 1
            pdfView = view
            imageScrollView = nil
            super.init(frame: .zero)
            embed(view)
        } else if let image = NSImage(contentsOf: fileURL) {
            let imageView = NSImageView(image: image)
            imageView.imageScaling = .scaleNone
            imageView.frame = NSRect(origin: .zero, size: image.size)

            let scrollView = NSScrollView()
            scrollView.documentView = imageView
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = true
            scrollView.allowsMagnification = true
            scrollView.minMagnification = 0.25
            scrollView.maxMagnification = 4
            imageScrollView = scrollView
            pdfView = nil
            super.init(frame: .zero)
            embed(scrollView)
        } else {
            pdfView = nil
            imageScrollView = nil
            super.init(frame: .zero)
            embed(NSTextField(labelWithString: "无法预览此文件。"))
        }
    }

    required init?(coder: NSCoder) { nil }

    func setZoom(_ scale: Double) {
        pdfView?.scaleFactor = CGFloat(scale)
        imageScrollView?.magnification = CGFloat(scale)
    }

    private func embed(_ view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
