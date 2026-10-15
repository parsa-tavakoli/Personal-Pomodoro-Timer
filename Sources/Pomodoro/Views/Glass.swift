import SwiftUI

extension SessionTimer {
    /// Colour of the current phase: accent for focus, teal for breaks (overtime keeps its phase colour).
    var accentColor: Color {
        Theme.Palette.mode(currentBlock?.kind ?? .focus)
    }
}
