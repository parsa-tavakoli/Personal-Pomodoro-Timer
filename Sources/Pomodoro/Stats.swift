import Foundation

struct DayTotal: Identifiable {
    let date: Date
    let seconds: TimeInterval
    var id: Date { date }
}

struct NameTotal: Identifiable {
    let key: String
    /// Most recent spelling of the name, or "Untitled".
    let displayName: String
    let seconds: TimeInterval
    let sessions: Int
    var id: String { key }
}

/// Aggregations behind the Stats page. A session counts on the day it started.
enum Stats {
    /// Grouping key: names match ignoring case and surrounding spaces.
    static func key(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? "untitled" : trimmed
    }

    /// Start of each of the last `count` days, oldest first, ending today.
    static func days(_ count: Int, calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<count).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    static func records(_ records: [SessionRecord], since: Date, nameKey: String?) -> [SessionRecord] {
        records.filter { $0.startedAt >= since && (nameKey == nil || key(for: $0.name) == nameKey) }
    }

    static func daily(_ records: [SessionRecord], days: [Date], nameKey: String?,
                      calendar: Calendar = .current) -> [DayTotal] {
        guard let first = days.first else { return [] }
        var totals: [Date: TimeInterval] = [:]
        for record in Self.records(records, since: first, nameKey: nameKey) {
            totals[calendar.startOfDay(for: record.startedAt), default: 0] += record.focusSeconds
        }
        return days.map { DayTotal(date: $0, seconds: totals[$0] ?? 0) }
    }

    /// Totals per session name since `since`, largest first.
    static func byName(_ records: [SessionRecord], since: Date) -> [NameTotal] {
        var groups: [String: (name: String, seconds: TimeInterval, sessions: Int)] = [:]
        // Newest first, so the first spelling seen for a key is the most recent one.
        for record in Self.records(records, since: since, nameKey: nil).sorted(by: { $0.startedAt > $1.startedAt }) {
            let k = key(for: record.name)
            var group = groups[k] ?? (record.displayName.trimmingCharacters(in: .whitespacesAndNewlines), 0, 0)
            group.seconds += record.focusSeconds
            group.sessions += 1
            groups[k] = group
        }
        return groups
            .map { NameTotal(key: $0.key, displayName: $0.value.name, seconds: $0.value.seconds, sessions: $0.value.sessions) }
            .sorted { $0.seconds != $1.seconds ? $0.seconds > $1.seconds : $0.displayName < $1.displayName }
    }
}

/// "45m", "2h" or "2h 5m".
func formatDuration(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds) / 60
    guard minutes >= 60 else { return "\(minutes)m" }
    return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
}
