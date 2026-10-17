import AppKit
import SwiftUI

struct TimerView: View {
    @EnvironmentObject private var timer: SessionTimer
    @EnvironmentObject private var updates: UpdateChecker
    @AppStorage("dismissedUpdate") private var dismissedUpdate = ""

    private var update: UpdateChecker.Update? {
        guard let update = updates.available, update.version != dismissedUpdate else { return nil }
        return update
    }

    var body: some View {
        // Rows sit a little closer while the update pill is showing, so everything still fits.
        VStack(spacing: update == nil ? 10 : 6) {
            if let update {
                UpdatePill(update: update) { dismissedUpdate = update.version }
            }
            ModeChips()
            RingView(clock: timer.clock)
            SessionProgress()
            TaskPill()
            TimerControls()
            Spacer(minLength: 0)
            TodayCard()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Ring and time. The only part of the Timer page that observes the ticking clock.
private struct RingView: View {
    @EnvironmentObject private var timer: SessionTimer
    @ObservedObject var clock: TimerClock

    var body: some View {
        // Content, so no glass. Scaled from the spec's 300/14 to fit the window.
        ZStack {
            ProgressRing(progress: timer.blockProgress, color: timer.accentColor, size: 196, lineWidth: 11)
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
        .accessibilityLabel(accessibilityText)
    }

    private var subtitle: String {
        let phase = timer.isInOvertime ? "Overtime" : (timer.currentBlock?.kind.rawValue ?? "Focus")
        return "\(phase) · \(timer.progressText.lowercased())"
    }

    private var accessibilityText: String {
        let phase = timer.currentBlock?.kind.rawValue ?? "Focus"
        let seconds = Int(timer.isInOvertime ? clock.overtime : clock.remaining)
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
    @EnvironmentObject private var projects: ProjectStore

    var body: some View {
        let project = projects.project(timer.projectID)
        HStack(spacing: Theme.Space.s) {
            ProjectMenu(selection: $timer.projectID) {
                // The dot is the menu: the project's colour, or the phase colour with no project.
                Circle()
                    .fill(project?.color ?? timer.accentColor)
                    .frame(width: 10, height: 10)
                    .overlay {
                        if project == nil {
                            Circle().strokeBorder(Theme.Palette.background.opacity(0.6), lineWidth: 2)
                        }
                    }
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .help(project.map { "Project: \($0.name)" } ?? "Choose a project")
            SessionNameField(text: $timer.sessionName, placeholder: "What are you working on?")
                .font(Theme.Fonts.body(14, .medium))
            if let project {
                Text(project.name)
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Theme.Palette.textMuted)
                    .lineLimit(1)
                    .fixedSize()
            }
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
    @Environment(\.isVisiblePage) private var isVisiblePage
    @Namespace private var glass

    /// One smooth curve for every morph; .bouncy's overshoot made the glass wobble.
    private let morph = Animation.smooth(duration: 0.45)

    var body: some View {
        // Shapes within the container spacing flow together while morphing. At rest
        // the gaps (22/24) stay well above it, so buttons never blend, even when pressed.
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: timer.isInOvertime ? 22 : 24) {
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
        .animation(morph, value: timer.state)
        .animation(morph, value: timer.isInOvertime)
        .animation(morph, value: timer.currentBlock?.kind)
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
        // Only while the Timer page is showing (other pages stay alive behind it).
        .keyboardShortcut(isVisiblePage ? KeyboardShortcut(.space, modifiers: []) : nil)
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
        // Compact so the row fits with 22 pt gaps.
        let label = Text(title)
            .font(Theme.Fonts.body(13, .semibold))
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

/// "Version 1.0.4 is available · Download". Dismissing hides it for that version only.
private struct UpdatePill: View {
    let update: UpdateChecker.Update
    let dismiss: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(Theme.Palette.accent)
            Text("Version \(update.version) is available")
            Text("·").foregroundStyle(Theme.Palette.textMuted)
            Button("Download") { openURL(update.url) }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Palette.accent)
                .fontWeight(.semibold)
            Spacer(minLength: 0)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.Palette.textMuted)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss update notice")
        }
        .font(Theme.Fonts.body(12))
        .padding(.horizontal, Theme.Space.m)
        .frame(height: 28)
        .background(Theme.Palette.accent.opacity(0.12), in: Capsule())
        .overlay { Capsule().strokeBorder(Theme.Palette.accent.opacity(0.35), lineWidth: 1) }
    }
}
