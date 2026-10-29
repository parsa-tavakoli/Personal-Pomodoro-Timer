import AppKit
import SwiftUI

/// A menu for choosing a session's project: "No project", every project, and "New project…".
/// Used by the Timer's task pill and by History (to change a past session's project).
struct ProjectMenu<Label: View>: View {
    @Binding var selection: UUID?
    @ViewBuilder var label: () -> Label

    @EnvironmentObject private var projects: ProjectStore

    var body: some View {
        Menu {
            ProjectMenuItems(selection: $selection)
        } label: {
            label()
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

/// The menu's items, also usable inside a context menu.
struct ProjectMenuItems: View {
    @Binding var selection: UUID?
    @EnvironmentObject private var projects: ProjectStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button {
            selection = nil
        } label: {
            Text(selection == nil ? "✓  No project" : "No project")
        }
        // Active projects, plus the selected one if it has since been archived.
        let shown = projects.projects.filter { !$0.archived || $0.id == selection }
        if !shown.isEmpty {
            Divider()
            ForEach(shown) { project in
                Button {
                    selection = project.id
                } label: {
                    Label {
                        let name = project.archived ? "\(project.name) (archived)" : project.name
                        Text(selection == project.id ? "\(name)  ✓" : name)
                    } icon: {
                        Image(nsImage: Project.dot(project.color))
                    }
                }
            }
        }
        Divider()
        Button("New Project…") {
            if let name = askForProjectName() {
                selection = projects.add(named: name).id
            }
        }
        Button("Manage Projects…") { openSettings() }
    }

    /// A small "New project" prompt (an alert with a text field; no SwiftUI @State needed).
    private func askForProjectName() -> String? {
        let alert = NSAlert()
        alert.messageText = "New project"
        alert.informativeText = "For example \"Thesis\" or \"Work\". You can change its colour in Settings."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "Project name"
        alert.accessoryView = field
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}
