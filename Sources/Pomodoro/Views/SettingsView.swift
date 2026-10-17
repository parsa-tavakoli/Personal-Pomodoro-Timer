import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var timer: SessionTimer
    @EnvironmentObject private var projects: ProjectStore

    var body: some View {
        Form {
            Section {
                Picker("Session type", selection: $timer.config.mode) {
                    ForEach(SessionMode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(timer.config.mode == .fixed
                     ? "A set number of pomodoros; breaks start automatically."
                     : "Start with one pomodoro. Each timer keeps counting past zero until you choose what's next.")
                    .foregroundStyle(.secondary)
            }
            Section("Timers (minutes)") {
                Stepper("Focus: \(timer.config.focusMinutes)", value: $timer.config.focusMinutes, in: 1...180)
                Stepper("Short break: \(timer.config.shortBreakMinutes)", value: $timer.config.shortBreakMinutes, in: 1...60)
                Stepper("Long break: \(timer.config.longBreakMinutes)", value: $timer.config.longBreakMinutes, in: 1...120)
            }
            if timer.config.mode == .fixed {
                Section("Session") {
                    Stepper("Pomodoros per session: \(timer.config.totalPomodoros)", value: $timer.config.totalPomodoros, in: 1...24)
                    Stepper("Long break every \(timer.config.pomodorosPerLongBreak) pomodoros", value: $timer.config.pomodorosPerLongBreak, in: 1...12)
                    LabeledContent("Total session length", value: totalLength)
                }
            }
            Section {
                ForEach(projects.projects) { project in
                    ProjectRow(project: project)
                }
                Button("Add Project") {
                    projects.add(named: "Project \(projects.projects.count + 1)")
                }
            } header: {
                Text("Projects")
            } footer: {
                Text("Group sessions such as \"Thesis\" or \"Work\". Only focus time counts towards a project.")
                    .foregroundStyle(.secondary)
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
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.background)
        .tint(Theme.Palette.accent)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var totalLength: String {
        let seconds = Session.blocks(for: timer.config).reduce(0) { $0 + $1.duration }
        let minutes = Int(seconds) / 60
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

/// One project in Settings: colour menu, editable name, delete.
private struct ProjectRow: View {
    let project: Project
    @EnvironmentObject private var projects: ProjectStore

    private var name: Binding<String> {
        Binding(get: { project.name }, set: { projects.rename(project.id, to: $0) })
    }

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(Project.colors.indices, id: \.self) { i in
                    Button {
                        projects.setColor(project.id, i)
                    } label: {
                        Label {
                            Text(i == project.colorIndex ? "\(Project.colors[i].name)  ✓" : Project.colors[i].name)
                        } icon: {
                            Image(nsImage: Project.dot(Project.colors[i].color))
                        }
                    }
                }
            } label: {
                Circle()
                    .fill(project.color)
                    .frame(width: 14, height: 14)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Colour")

            // Labels hidden: in a Form the title would otherwise sit on the left, the name on the right.
            TextField("Project name", text: name)
                .textFieldStyle(.plain)
                .labelsHidden()
                .multilineTextAlignment(.leading)

            Button(role: .destructive) {
                projects.delete(project.id)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete project (its sessions keep their history)")
        }
    }
}
