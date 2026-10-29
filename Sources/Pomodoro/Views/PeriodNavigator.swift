import SwiftUI

/// "‹  label  [Today]  ›" row for stepping through weeks (History) or days (Stats).
/// › is disabled on the current period; Today appears only away from it.
struct PeriodNavigator: View {
    let label: String
    let isCurrent: Bool
    /// What one step is called in accessibility labels, e.g. "week" or "day".
    let unit: String
    let onBack: () -> Void
    let onForward: () -> Void
    let onToday: () -> Void

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            arrow("chevron.left", label: "Previous \(unit)", action: onBack)
            Spacer(minLength: 0)
            Text(label)
                .font(Theme.Fonts.body(13, .medium))
                .foregroundStyle(Theme.Palette.textMuted)
            if !isCurrent {
                Button("Today", action: onToday)
                    .buttonStyle(.plain)
                    .font(Theme.Fonts.body(12, .semibold))
                    .foregroundStyle(Theme.Palette.accent)
                    .padding(.leading, 4)
            }
            Spacer(minLength: 0)
            arrow("chevron.right", label: "Next \(unit)", action: onForward)
                .disabled(isCurrent)
                .opacity(isCurrent ? 0.3 : 1)
        }
        .frame(height: 24)
    }

    private func arrow(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}
