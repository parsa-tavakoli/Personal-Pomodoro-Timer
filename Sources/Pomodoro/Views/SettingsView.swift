import SwiftUI

/// Settings window: General (timers) and Projects & Tasks (manage, archive, delete).
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "timer") }
            ProjectsTasksSettings()
                .tabItem { Label("Projects & Tasks", systemImage: "folder") }
        }
        .tint(Theme.Palette.accent)
    }
}

private struct GeneralSettings: View {
    @EnvironmentObject private var timer: SessionTimer

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

/// Projects (active and archived) and every task name in your history.
private struct ProjectsTasksSettings: View {
    @EnvironmentObject private var projects: ProjectStore
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var archive: TaskArchive

    var body: some View {
        let tasks = Stats.byName(history.records, since: .distantPast)
        Form {
            Section {
                ForEach(projects.activeProjects) { project in
                    ProjectRow(project: project)
                }
                Button("Add Project") {
                    projects.add(named: "Project \(projects.projects.count + 1)")
                }
            } header: {
                Text("Projects")
            } footer: {
                Text("Group sessions such as \"Thesis\" or \"Work\". Only focus time counts towards a project. Archived projects leave the picker and Stats lists; their history is kept.")
                    .foregroundStyle(.secondary)
            }
            if !projects.archivedProjects.isEmpty {
                Section("Archived projects") {
                    ForEach(projects.archivedProjects) { project in
                        ProjectRow(project: project)
                    }
                }
            }
            Section {
                let active = tasks.filter { !archive.isArchived($0.key) }
                if active.isEmpty {
                    Text("Tasks are the names you type in \"What are you working on?\".")
                        .foregroundStyle(.secondary)
                }
                ForEach(active) { TaskRow(task: $0) }
            } header: {
                Text("Tasks")
            } footer: {
                Text("Deleting a task deletes all of its sessions.")
                    .foregroundStyle(.secondary)
            }
            let archived = tasks.filter { archive.isArchived($0.key) }
            if !archived.isEmpty {
                Section("Archived tasks") {
                    ForEach(archived) { TaskRow(task: $0) }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.background)
        .tint(Theme.Palette.accent)
        .frame(width: 380, height: 420)
    }
}

/// One task in Settings: name, sessions and focus, archive, delete.
private struct TaskRow: View {
    let task: NameTotal
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var archive: TaskArchive

    var body: some View {
        let archived = archive.isArchived(task.key)
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.displayName)
                    .lineLimit(1)
                Text("\(task.sessions) session\(task.sessions == 1 ? "" : "s") · \(formatDuration(task.seconds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            IconButton(archived ? "tray.and.arrow.up" : "archivebox",
                       help: archived ? "Unarchive task" : "Archive task") {
                archive.setArchived(task.key, !archived)
            }
            IconButton("trash", help: "Delete task and its sessions") {
                ArchiveActions.deleteTask(key: task.key, name: task.displayName, history: history, archive: archive)
            }
        }
    }
}

/// Small borderless icon button used in the Settings rows.
private struct IconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    init(_ symbol: String, help: String, action: @escaping () -> Void) {
        self.symbol = symbol
        self.help = help
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// One project in Settings: colour menu, editable name, archive, delete.
private struct ProjectRow: View {
    let project: Project
    @EnvironmentObject private var projects: ProjectStore
    @EnvironmentObject private var history: HistoryStore

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

            IconButton(project.archived ? "tray.and.arrow.up" : "archivebox",
                       help: project.archived ? "Unarchive project" : "Archive project") {
                projects.setArchived(project.id, !project.archived)
            }
            IconButton("trash", help: "Delete project (its sessions stay as No project)") {
                ArchiveActions.deleteProject(project, projects: projects, history: history)
            }
        }
    }
}
