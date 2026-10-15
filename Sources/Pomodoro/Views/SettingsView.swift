import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var timer: SessionTimer

    var body: some View {
        Form {
            Section("Timers (minutes)") {
                Stepper("Focus: \(timer.config.focusMinutes)", value: $timer.config.focusMinutes, in: 1...180)
                Stepper("Short break: \(timer.config.shortBreakMinutes)", value: $timer.config.shortBreakMinutes, in: 1...60)
                Stepper("Long break: \(timer.config.longBreakMinutes)", value: $timer.config.longBreakMinutes, in: 1...120)
            }
            Section("Session") {
                Stepper("Pomodoros per session: \(timer.config.totalPomodoros)", value: $timer.config.totalPomodoros, in: 1...24)
                Stepper("Long break every \(timer.config.pomodorosPerLongBreak) pomodoros", value: $timer.config.pomodorosPerLongBreak, in: 1...12)
                LabeledContent("Total session length", value: totalLength)
            }
            Section {
                Button("Reset to defaults") { timer.config = SessionConfig() }
            } footer: {
                if timer.state != .idle {
                    Text("Changes apply to the next session.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var totalLength: String {
        let seconds = Session.blocks(for: timer.config).reduce(0) { $0 + $1.duration }
        let minutes = Int(seconds) / 60
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
