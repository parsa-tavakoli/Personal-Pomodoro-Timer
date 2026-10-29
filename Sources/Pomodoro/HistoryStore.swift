import Foundation

/// Saves finished sessions as JSON in Application Support.
@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [SessionRecord] = []

    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pomodoro", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("history.json")
        load()
    }

    func add(_ record: SessionRecord) {
        records.insert(record, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        save()
    }

    func delete(_ record: SessionRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = records.firstIndex(where: { $0.id == id }) else { return }
        // Names are single-line (e.g. pasted text); spaces are kept so typing between words works.
        records[i].name = name.filter { !$0.isNewline }
        save()
    }

    /// Deletes every session whose name is the task `key` (see `Stats.key(for:)`). Returns how many.
    @discardableResult
    func deleteSessions(taskKey key: String) -> Int {
        let before = records.count
        records.removeAll { Stats.key(for: $0.name) == key }
        save()
        return before - records.count
    }

    func setProject(_ id: UUID, to projectID: UUID?) {
        guard let i = records.firstIndex(where: { $0.id == id }) else { return }
        records[i].projectID = projectID
        save()
    }

    /// Total focus seconds for sessions started on or after `date`.
    func focusSeconds(since date: Date) -> TimeInterval {
        records.filter { $0.startedAt >= date }.reduce(0) { $0 + $1.focusSeconds }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        records = (try? decoder.decode([SessionRecord].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
