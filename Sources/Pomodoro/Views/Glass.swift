import SwiftUI

extension SessionTimer {
    /// Colour of the current phase: red for focus, green for breaks, orange in overtime.
    var accentColor: Color {
        if isInOvertime { return .orange }
        return currentBlock?.kind == .focus ? .red : .green
    }
}

/// Soft colour wash behind the window content. It's the content layer the
/// Liquid Glass toolbar and buttons refract, and it follows the current phase.
struct AmbientBackground: View {
    @EnvironmentObject private var timer: SessionTimer

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(
                colors: [timer.accentColor.opacity(timer.state == .idle ? 0.12 : 0.28), .clear],
                center: .top, startRadius: 0, endRadius: 420
            )
            RadialGradient(
                colors: [timer.accentColor.opacity(0.10), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 320
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: timer.accentColor)
        .animation(.easeInOut(duration: 0.6), value: timer.state)
    }
}
