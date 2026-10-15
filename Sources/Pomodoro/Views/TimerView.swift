import SwiftUI

struct TimerView: View {
    @EnvironmentObject private var timer: SessionTimer

    private var tint: Color {
        if timer.isInOvertime { return .orange }
        return timer.currentBlock?.kind == .focus ? .red : .green
    }

    private var title: String {
        guard let block = timer.currentBlock else { return "" }
        return timer.isInOvertime ? "\(block.kind.rawValue) · Overtime" : block.kind.rawValue
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)

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
            }
            .frame(width: 220, height: 220)

            SessionProgress()

            if timer.isInOvertime {
                OvertimeChoices()
            } else {
                controls
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button(action: timer.toggle) {
                Text(timer.state == .running ? "Pause" : (timer.state == .paused ? "Resume" : "Start"))
                    .frame(width: 80)
            }
            .keyboardShortcut(.space, modifiers: [])
            .buttonStyle(.borderedProminent)
            .tint(tint)

            Button("Skip", action: timer.skip)
                .disabled(timer.state == .idle)
            Button("Stop", role: .destructive, action: timer.stop)
                .disabled(timer.state == .idle)
        }
        .controlSize(.large)
    }
}

/// Flexible mode: what to do once a countdown has run into overtime.
private struct OvertimeChoices: View {
    @EnvironmentObject private var timer: SessionTimer

    var body: some View {
        HStack(spacing: 10) {
            if timer.currentBlock?.kind == .focus {
                Button("Short Break") { timer.continueWithBreak(.shortBreak) }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                Button("Long Break") { timer.continueWithBreak(.longBreak) }
            } else {
                Button("Start Next Pomodoro", action: timer.startNextPomodoro)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
            Button("End Session", role: .destructive, action: timer.stop)
        }
        .controlSize(.large)
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
