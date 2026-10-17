import AppKit
import SwiftUI

/// A project or tag that groups sessions, e.g. "Thesis" or "Work". Only focus time counts.
struct Project: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    /// Index into `Project.colors`.
    var colorIndex: Int

    var color: Color { Project.colors[colorIndex % Project.colors.count].color }

    /// The ten project colours (kept clear of the break teal).
    static let colors: [(name: String, color: Color)] = [
        ("Coral", Color(hex: 0xFF6B4A)),
        ("Amber", Color(hex: 0xF2B84B)),
        ("Lime", Color(hex: 0xA3D65C)),
        ("Mint", Color(hex: 0x5BD6A0)),
        ("Sky", Color(hex: 0x4FC3F7)),
        ("Blue", Color(hex: 0x7AA2FF)),
        ("Violet", Color(hex: 0xA78BFA)),
        ("Pink", Color(hex: 0xF472B6)),
        ("Sand", Color(hex: 0xC9A27A)),
        ("Slate", Color(hex: 0x94A3B8)),
    ]

    /// A coloured dot for menus (menu items draw SF Symbols in a single colour).
    static func dot(_ color: Color, size: CGFloat = 10) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSColor(color).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}

/// Saves projects as JSON in Application Support, next to the history.
@MainActor
final class ProjectStore: ObservableObject {
    @Published private(set) var projects: [Project] = []

    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pomodoro", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("projects.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([Project].self, from: data) {
            projects = saved
        }
    }

    func project(_ id: UUID?) -> Project? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }

    /// Adds a project with the next unused colour, and returns it.
    @discardableResult
    func add(named name: String) -> Project {
        let used = Set(projects.map(\.colorIndex))
        let color = (0..<Project.colors.count).first { !used.contains($0) } ?? projects.count % Project.colors.count
        let project = Project(name: name.trimmingCharacters(in: .whitespacesAndNewlines), colorIndex: color)
        projects.append(project)
        save()
        return project
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[i].name = name.filter { !$0.isNewline }
        save()
    }

    func setColor(_ id: UUID, _ colorIndex: Int) {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[i].colorIndex = colorIndex
        save()
    }

    /// Sessions keep their old project ID; with the project gone they count as "No project".
    func delete(_ id: UUID) {
        projects.removeAll { $0.id == id }
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(projects) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
