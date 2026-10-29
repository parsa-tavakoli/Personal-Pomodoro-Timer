import AppKit

/// Confirmed delete actions shared by Settings and Stats (NSAlert, so no SwiftUI @State).
@MainActor
enum ArchiveActions {
    /// Deletes a project after confirming. Its sessions stay, as "No project".
    static func deleteProject(_ project: Project, projects: ProjectStore, history: HistoryStore) {
        let count = history.records.filter { $0.projectID == project.id }.count
        let sessions = "\(count) session\(count == 1 ? "" : "s")"
        guard confirm(title: "Delete \(project.name)?",
                      message: count == 0
                        ? "It has no sessions."
                        : "Its \(sessions) stay in your history as No project.",
                      button: "Delete Project") else { return }
        projects.delete(project.id)
    }

    /// Deletes a task, meaning every session with that name, after confirming.
    static func deleteTask(key: String, name: String, history: HistoryStore, archive: TaskArchive) {
        let count = history.records.filter { Stats.key(for: $0.name) == key }.count
        let sessions = "\(count) session\(count == 1 ? "" : "s")"
        guard confirm(title: "Delete \u{201C}\(name)\u{201D} and its \(sessions)?",
                      message: "They're removed from History and Stats. This can't be undone.",
                      button: "Delete \(sessions.capitalized)") else { return }
        history.deleteSessions(taskKey: key)
        archive.remove(key)
    }

    private static func confirm(title: String, message: String, button: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        return alert.runModal() == .alertFirstButtonReturn
    }
}
