import AppKit
import SwiftUI

struct TimerView: View {
    @EnvironmentObject private var timer: SessionTimer

    private var tint: Color { timer.accentColor }

    var body: some View {
        VStack(spacing: 10) {
            ModeChips()
            ring
            SessionProgress()
            TaskPill()
            TimerControls()
            Spacer(minLength: 0)
            TodayCard()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Content, so no glass. Scaled from the spec's 300/14 to fit the window.
    private var ring: some View {
        ZStack {
            ProgressRing(progress: timer.blockProgress, color: tint, size: 196, lineWidth: 11)
            VStack(spacing: 4) {
                Text(timer.remainingText)
                    .font(Theme.Fonts.mono(46))
                    .tracking(-1)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                Text(subtitle)
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Theme.Palette.textMuted)
            }
            .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ringAccessibilityLabel)
    }

    private var subtitle: String {
        let phase = timer.isInOvertime ? "Overtime" : (timer.currentBlock?.kind.rawValue ?? "Focus")
        return "\(phase) · \(timer.progressText.lowercased())"
    }

    private var ringAccessibilityLabel: String {
        let phase = timer.currentBlock?.kind.rawValue ?? "Focus"
        let seconds = Int(timer.isInOvertime ? timer.overtime : timer.remaining)
        let time = "\(seconds / 60) minutes \(seconds % 60) seconds"
        return timer.isInOvertime ? "\(phase) overtime, \(time) over" : "\(phase) session, \(time) left"
    }
}

/// Focus · Short break · Long break. Indicators only: the session drives the phase.
private struct ModeChips: View {
    @EnvironmentObject private var timer: SessionTimer

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            ForEach([Block.Kind.focus, .shortBreak, .longBreak], id: \.self) { kind in
                let selected = timer.currentBlock?.kind == kind
                Text(kind == .focus ? "Focus" : (kind == .shortBreak ? "Short break" : "Long break"))
                    .font(Theme.Fonts.body(13, selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Theme.Palette.onAccent : Theme.Palette.textMuted)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(selected ? Theme.Palette.mode(kind) : .clear, in: Capsule())
            }
        }
        .animation(.easeInOut(duration: 0.25), value: timer.currentBlock?.kind)
        .accessibilityElement(children: .combine)
    }
}

/// The spec's current-task picker. Until Tasks exists it edits the session name.
private struct TaskPill: View {
    @EnvironmentObject private var timer: SessionTimer

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Circle()
                .fill(timer.accentColor)
                .frame(width: 8, height: 8)
            SessionNameField(text: $timer.sessionName, placeholder: "What are you working on?")
                .font(Theme.Fonts.body(14, .medium))
        }
        .padding(.horizontal, Theme.Space.m)
        .frame(height: 40)
        .card(radius: Theme.Radius.button, bordered: true)
    }
}

/// Today's totals, from history.
private struct TodayCard: View {
    @EnvironmentObject private var history: HistoryStore

    var body: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let sessions = history.records.filter { $0.startedAt >= today }.count
        let focus = formatDuration(history.focusSeconds(since: today))
        HStack {
            Text("Today")
                .foregroundStyle(Theme.Palette.textMuted)
            Spacer()
            Text("**\(sessions)** session\(sessions == 1 ? "" : "s") · **\(focus)** focus")
        }
        .font(Theme.Fonts.body(13))
        .padding(.horizontal, Theme.Space.l)
        .frame(height: 36)
        .card(radius: Theme.Radius.row)
    }
}

/// The control bar keeps Liquid Glass. All buttons share one GlassEffectContainer
/// so they morph between the playback circles and the overtime choices.
private struct TimerControls: View {
    @EnvironmentObject private var timer: SessionTimer
    @Namespace private var glass

    var body: some View {
        // Glass shapes closer than the container spacing blend into one blob, so keep
        // the gaps (12/24) well above it; glassEffectID still morphs between states.
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: timer.isInOvertime ? Theme.Space.m : 24) {
                if timer.isInOvertime {
                    overtimeChoices
                } else {
                    playbackControls
                }
            }
        }
        .frame(height: 64)
        // The keyboard focus ring clashes with the glass; Space still toggles.
        .focusEffectDisabled()
        .animation(.bouncy, value: timer.state)
        .animation(.bouncy, value: timer.isInOvertime)
        .animation(.bouncy, value: timer.currentBlock?.kind)
    }

    @ViewBuilder private var playbackControls: some View {
        circleButton("arrow.counterclockwise", size: 44, label: "Reset", action: timer.stop)
            .disabled(timer.state == .idle)
            .glassEffectID("end", in: glass)

        Button(action: timer.toggle) {
            Image(systemName: timer.state == .running ? "pause.fill" : "play.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.Palette.onAccent)
                .frame(width: 64, height: 64)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        .tint(timer.accentColor)
        .keyboardShortcut(.space, modifiers: [])
        .accessibilityLabel(timer.state == .running ? "Pause" : (timer.state == .paused ? "Resume" : "Start"))
        .glassEffectID("primary", in: glass)

        circleButton("forward.end", size: 44,
                     label: timer.currentBlock?.kind == .focus ? "Skip to break" : "Skip to focus",
                     action: timer.skip)
            .disabled(timer.state == .idle)
            .glassEffectID("secondary", in: glass)
    }

    @ViewBuilder private var overtimeChoices: some View {
        if timer.currentBlock?.kind == .focus {
            textButton("Short break", prominent: Theme.Palette.breakColor) { timer.continueWithBreak(.shortBreak) }
                .glassEffectID("primary", in: glass)
            textButton("Long break") { timer.continueWithBreak(.longBreak) }
                .glassEffectID("secondary", in: glass)
        } else {
            textButton("Next pomodoro", prominent: Theme.Palette.accent, action: timer.startNextPomodoro)
                .glassEffectID("primary", in: glass)
        }
        textButton("End", action: timer.stop)
            .glassEffectID("end", in: glass)
    }

    private func circleButton(_ symbol: String, size: CGFloat, label: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: size, height: size)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(label)
        .help(label)
    }

    @ViewBuilder
    private func textButton(_ title: String, prominent: Color? = nil,
                            action: @escaping () -> Void) -> some View {
        let label = Text(title)
            .font(Theme.Fonts.body(14, .semibold))
            .padding(.horizontal, 6)
            .frame(minHeight: 32)
        if let prominent {
            Button(action: action) { label.foregroundStyle(Theme.Palette.onAccent) }
                .buttonStyle(.glassProminent)
                .tint(prominent)
                .controlSize(.large)
        } else {
            Button(action: action) { label.foregroundStyle(Theme.Palette.textPrimary) }
                .buttonStyle(.glass)
                .controlSize(.large)
        }
    }
}

/// One pip per pomodoro in the session (spec: cycle dots).
private struct SessionProgress: View {
    @EnvironmentObject private var timer: SessionTimer

    var body: some View {
        let current = timer.currentBlock
        HStack(spacing: Theme.Space.s) {
            ForEach(1...max(1, timer.pomodoroCount), id: \.self) { n in
                Pip(state: state(for: n, current: current), color: timer.accentColor)
            }
        }
        .frame(height: Theme.Size.pip)
        .accessibilityHidden(true)
    }

    private func state(for n: Int, current: Block?) -> Pip.State {
        guard let current else { return .upcoming }
        if n < current.pomodoro || (n == current.pomodoro && current.kind != .focus) { return .done }
        if n == current.pomodoro && timer.state != .idle { return .current }
        return .upcoming
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
