import Foundation

struct DayTotal: Identifiable {
    let date: Date
    let seconds: TimeInterval
    var pomodoros: Int = 0
    var id: Date { date }
}

struct NameTotal: Identifiable {
    let key: String
    /// Most recent spelling of the name, or "Untitled session".
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

    /// Monday to Sunday of the current week (always Monday-first, whatever the region).
    static func currentWeek(calendar: Calendar = .current) -> [Date] {
        var cal = calendar
        cal.firstWeekday = 2
        let start = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? cal.startOfDay(for: Date())
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
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
        var totals: [Date: (seconds: TimeInterval, pomodoros: Int)] = [:]
        for record in Self.records(records, since: first, nameKey: nameKey) {
            let day = calendar.startOfDay(for: record.startedAt)
            totals[day, default: (0, 0)].seconds += record.focusSeconds
            totals[day, default: (0, 0)].pomodoros += record.completedPomodoros
        }
        return days.map { DayTotal(date: $0, seconds: totals[$0]?.seconds ?? 0, pomodoros: totals[$0]?.pomodoros ?? 0) }
    }

    /// Days in a row with at least one session, ending today (or yesterday, if today has none yet).
    static func streak(_ records: [SessionRecord], calendar: Calendar = .current) -> Int {
        let active = Set(records.map { calendar.startOfDay(for: $0.startedAt) })
        var day = calendar.startOfDay(for: Date())
        if !active.contains(day), let yesterday = calendar.date(byAdding: .day, value: -1, to: day) {
            day = yesterday
        }
        var count = 0
        while active.contains(day), let previous = calendar.date(byAdding: .day, value: -1, to: day) {
            count += 1
            day = previous
        }
        return count
    }

    /// Sessions started in each hour of `hours` (e.g. 8..<18). Approximate: whole
    /// sessions are counted by their start hour until per-block times are logged.
    /// Focus seconds in each hour of the day, from the logged focus blocks. A block that
    /// crosses an hour boundary is split between both hours. Sessions saved before block
    /// logging have no blocks, so their focus time goes to the hour they started.
    static func focusByHour(_ records: [SessionRecord], since: Date, nameKey: String?,
                            hours: Range<Int>, calendar: Calendar = .current) -> [TimeInterval] {
        var totals = [TimeInterval](repeating: 0, count: hours.count)
        func add(_ seconds: TimeInterval, at date: Date) {
            let hour = calendar.component(.hour, from: date)
            if hours.contains(hour) { totals[hour - hours.lowerBound] += seconds }
        }
        for record in Self.records(records, since: since, nameKey: nameKey) {
            let focus = record.blocks.filter { $0.kind == .focus }
            guard !focus.isEmpty else {
                add(record.focusSeconds, at: record.startedAt)
                continue
            }
            for block in focus {
                var cursor = block.start
                while cursor < block.end {
                    let hourStart = calendar.dateInterval(of: .hour, for: cursor)?.start ?? cursor
                    let nextHour = calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? block.end
                    let pieceEnd = min(nextHour, block.end)
                    add(pieceEnd.timeIntervalSince(cursor), at: cursor)
                    cursor = pieceEnd
                }
            }
        }
        return totals
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
