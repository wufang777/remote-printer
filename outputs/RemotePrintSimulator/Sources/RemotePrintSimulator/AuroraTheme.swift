import SwiftUI
import RemotePrintCore

enum AuroraTheme {
    static let primaryGradient = LinearGradient(
        colors: [Color(red: 0.15, green: 0.46, blue: 1), Color(red: 0.21, green: 0.78, blue: 0.97)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func statusColor(_ status: PrintJobStatus) -> Color {
        let hex: String
        switch status {
        case .printing: hex = AuroraStatusColor.printing.rawValue
        case .succeeded: hex = AuroraStatusColor.succeeded.rawValue
        case .failed, .cancelled: hex = AuroraStatusColor.failed.rawValue
        case .received, .awaitingConfirmation: hex = AuroraStatusColor.waiting.rawValue
        }
        return Color(hex: hex)
    }
}

struct AuroraGlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(24)
            .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.9), lineWidth: 1))
            .shadow(color: Color.blue.opacity(0.10), radius: 22, y: 10)
    }
}

struct AuroraPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(Color(red: 0.03, green: 0.10, blue: 0.24))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(AuroraTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .blue.opacity(configuration.isPressed ? 0.12 : 0.30), radius: 14, y: 7)
            .opacity(configuration.isPressed ? 0.86 : 1)
    }
}

private extension Color {
    init(hex: String) {
        let value = UInt64(hex.dropFirst(), radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
