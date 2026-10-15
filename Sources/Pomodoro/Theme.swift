//  Theme.swift
//  Design tokens for the Pomodoro redesign. See DESIGN.md.
//
//  Custom fonts are optional: if Space Grotesk / IBM Plex Sans / JetBrains Mono
//  are installed they are used; otherwise the system fallbacks below kick in.
//  Adapted for this macOS app: no UIKit branch, mode colours, sizable ring.

import AppKit
import SwiftUI

enum Theme {

    // MARK: Colors
    enum Palette {
        static let background    = Color(hex: 0x0F1115)
        static let surface       = Color(hex: 0x171A20)
        static let surfaceRaised = Color(hex: 0x1C2028)
        static let surfaceSunken = Color(hex: 0x15181E)
        static let stroke        = Color(hex: 0x262A33)
        static let divider       = Color(hex: 0x1F232B)
        static let inactive      = Color(hex: 0x3A3F4A)

        static let textPrimary   = Color(hex: 0xEDEEF0)
        static let textMuted     = Color(hex: 0x9AA0AA)
        static let textFaint     = Color(hex: 0x6B7280)

        static let accent        = Color(hex: 0xFF6B4A)   // focus
        static let onAccent      = Color(hex: 0x14161B)
        static let breakColor    = Color(hex: 0x3FB8AF)   // breaks / done

        /// Accent for focus, teal for breaks.
        static func mode(_ kind: Block.Kind) -> Color {
            kind == .focus ? accent : breakColor
        }

        /// Alternative accents explored in the design.
        static let accentOptions: [Color] = [
            Color(hex: 0xFF6B4A), Color(hex: 0xF2B84B),
            Color(hex: 0x7AA2FF), Color(hex: 0x3FB8AF)
        ]
    }

    // MARK: Radii
    enum Radius {
        static let chip: CGFloat   = 18
        static let button: CGFloat = 12
        static let row: CGFloat    = 14
        static let card: CGFloat   = 16
        static let bigCard: CGFloat = 18
        static let bar: CGFloat    = 6
    }

    // MARK: Spacing (4-pt grid)
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat  = 8
        static let m: CGFloat  = 12
        static let l: CGFloat  = 16
        static let screen: CGFloat = 20   // side margin
        static let title: CGFloat  = 24   // title side margin
    }

    enum Size {
        static let minTap: CGFloat     = 44
        static let ring: CGFloat       = 300
        static let ringLine: CGFloat   = 14
        static let playButton: CGFloat = 80
        static let sideButton: CGFloat = 56
        static let pip: CGFloat        = 10
    }

    // MARK: Fonts
    enum Fonts {
        static func display(_ size: CGFloat) -> Font {
            custom("SpaceGrotesk-Bold", size, fallback: .system(size: size, weight: .bold, design: .rounded))
        }
        static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
            let name: String
            switch weight {
            case .semibold, .bold, .heavy, .black: name = "IBMPlexSans-SemiBold"
            case .medium: name = "IBMPlexSans-Medium"
            default: name = "IBMPlexSans-Regular"
            }
            return custom(name, size, fallback: .system(size: size, weight: weight))
        }
        static func mono(_ size: CGFloat) -> Font {
            custom("JetBrainsMono-Medium", size, fallback: .system(size: size, weight: .medium, design: .monospaced))
        }

        // Named styles used in DESIGN.md
        static let timerLarge   = mono(64)
        static let timerCompact = mono(34)
        static let screenTitle  = display(28)
        static let appName      = display(20)
        static let statValue    = display(22)

        private static func custom(_ name: String, _ size: CGFloat, fallback: Font) -> Font {
            NSFont(name: name, size: size) != nil ? .custom(name, size: size) : fallback
        }
    }
}

// MARK: - Helpers

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8)  & 0xFF) / 255,
                  blue:  Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Flat card: surface fill, optional 1pt stroke.
struct CardStyle: ViewModifier {
    var radius: CGFloat = Theme.Radius.card
    var bordered: Bool = false
    func body(content: Content) -> some View {
        content
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                if bordered {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Theme.Palette.stroke, lineWidth: 1)
                }
            }
    }
}

extension View {
    func card(radius: CGFloat = Theme.Radius.card, bordered: Bool = false) -> some View {
        modifier(CardStyle(radius: radius, bordered: bordered))
    }
}

/// Pomodoro pip: filled = done, outlined accent = in progress, outlined grey = upcoming.
struct Pip: View {
    enum State { case done, current, upcoming }
    var state: State
    var color: Color = Theme.Palette.accent
    var body: some View {
        Group {
            switch state {
            case .done:     Circle().fill(color)
            case .current:  Circle().strokeBorder(color, lineWidth: 2)
            case .upcoming: Circle().strokeBorder(Theme.Palette.inactive, lineWidth: 2)
            }
        }
        .frame(width: Theme.Size.pip, height: Theme.Size.pip)
    }
}

/// Progress ring used on the Timer screen.
struct ProgressRing: View {
    var progress: Double          // 0...1 elapsed
    var color: Color = Theme.Palette.accent
    // Scaled down from the spec's 300/14 to fit the compact window.
    var size: CGFloat = Theme.Size.ring
    var lineWidth: CGFloat = Theme.Size.ringLine
    var body: some View {
        ZStack {
            Circle().stroke(Theme.Palette.divider, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
        .frame(width: size, height: size)
    }
}
