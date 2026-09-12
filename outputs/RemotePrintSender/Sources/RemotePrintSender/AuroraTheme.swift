import SwiftUI

enum AuroraTheme {
    static let background = LinearGradient(
        colors: [Color(red: 0.88, green: 0.96, blue: 1), Color(red: 0.95, green: 0.91, blue: 1), Color.white],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let accent = LinearGradient(colors: [.blue, .cyan, .purple], startPoint: .leading, endPoint: .trailing)
}

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content.padding(26)
            .background(.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.95)))
            .shadow(color: .blue.opacity(0.12), radius: 22, y: 10)
    }
}
