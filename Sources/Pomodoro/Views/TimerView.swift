import AppKit
import SwiftUI

struct TimerView: View {
    @EnvironmentObject private var timer: SessionTimer

    private var tint: Color { timer.accentColor }

    private var title: String {
        guard let block = timer.currentBlock else { return "" }
        return timer.isInOvertime ? "\(block.kind.rawValue) · Overtime" : block.kind.rawValue
    }

    var body: some View {
        VStack(spacing: 20) {
            SessionNameField(text: $timer.sessionName, placeholder: "Name this session")
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)

            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
                .contentTransition(.interpolate)

            // The ring is content, so it stays plain (no glass).
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.15), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: timer.blockProgress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: timer.blockProgress)
                Text(timer.remainingText)
                    .font(.system(size: 56, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .frame(width: 220, height: 220)

            SessionProgress()

            TimerControls()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The control bar. All buttons share one GlassEffectContainer so they sample the
/// same backdrop and morph into each other as the session changes state:
/// Start → Pause/Skip/Stop → overtime choices (flexible mode).
private struct TimerControls: View {
    @EnvironmentObject private var timer: SessionTimer
    @Namespace private var glass

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 10) {
                if timer.isInOvertime {
                    overtimeChoices
                } else {
                    playbackControls
                }
            }
        }
        .controlSize(.large)
        // The keyboard focus ring clashes with the glass; Space still toggles.
        .focusEffectDisabled()
        .animation(.bouncy, value: timer.state)
        .animation(.bouncy, value: timer.isInOvertime)
        .animation(.bouncy, value: timer.currentBlock?.kind)
    }

    @ViewBuilder private var playbackControls: some View {
        Button(action: timer.toggle) {
            Label(primaryTitle, systemImage: primarySymbol)
                .frame(minWidth: 84)
        }
        .keyboardShortcut(.space, modifiers: [])
        .buttonStyle(.glassProminent)
        .tint(timer.accentColor)
        .glassEffectID("primary", in: glass)

        if timer.state != .idle {
            Button("Skip", systemImage: "forward.end.fill", action: timer.skip)
                .buttonStyle(.glass)
                .glassEffectID("secondary", in: glass)
            Button("Stop", systemImage: "stop.fill", role: .destructive, action: timer.stop)
                .buttonStyle(.glass)
                .glassEffectID("end", in: glass)
        }
    }

    @ViewBuilder private var overtimeChoices: some View {
        if timer.currentBlock?.kind == .focus {
            Button("Short Break") { timer.continueWithBreak(.shortBreak) }
                .buttonStyle(.glassProminent)
                .tint(.green)
                .glassEffectID("primary", in: glass)
            Button("Long Break") { timer.continueWithBreak(.longBreak) }
                .buttonStyle(.glass)
                .glassEffectID("secondary", in: glass)
        } else {
            Button("Next Pomodoro", systemImage: "play.fill", action: timer.startNextPomodoro)
                .buttonStyle(.glassProminent)
                .tint(.red)
                .glassEffectID("primary", in: glass)
        }
        Button("End", systemImage: "stop.fill", role: .destructive, action: timer.stop)
            .buttonStyle(.glass)
            .glassEffectID("end", in: glass)
    }

    private var primaryTitle: String {
        switch timer.state {
        case .idle: return "Start"
        case .running: return "Pause"
        case .paused: return "Resume"
        }
    }

    private var primarySymbol: String {
        timer.state == .running ? "pause.fill" : "play.fill"
    }
}

/// One dot per pomodoro in the session; filled once its focus block is done.
private struct SessionProgress: View {
    @EnvironmentObject private var timer: SessionTimer

    var body: some View {
        let current = timer.currentBlock
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(1...max(1, timer.pomodoroCount), id: \.self) { n in
                    Circle()
                        .fill(fill(for: n, current: current))
                        .frame(width: 10, height: 10)
                }
            }
            Text(timer.progressText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func fill(for n: Int, current: Block?) -> Color {
        guard let current else { return .secondary.opacity(0.3) }
        let done = n < current.pomodoro || (n == current.pomodoro && current.kind != .focus)
        if done { return .red }
        if n == current.pomodoro && timer.state != .idle { return .red.opacity(0.45) }
        return .secondary.opacity(0.3)
    }
}

/// Plain inline text field for a session name. Return ends editing so the
/// keyboard goes back to the timer shortcuts.
struct SessionNameField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .onSubmit { NSApp.keyWindow?.makeFirstResponder(nil) }
    }
}
