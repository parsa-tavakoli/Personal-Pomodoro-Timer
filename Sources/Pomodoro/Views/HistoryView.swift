import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var history: HistoryStore

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatTile(title: "Today", seconds: history.focusSeconds(since: Calendar.current.startOfDay(for: Date())))
                StatTile(title: "This week", seconds: history.focusSeconds(since: startOfWeek))
            }

            if history.records.isEmpty {
                ContentUnavailableView("No sessions yet", systemImage: "tray",
                                       description: Text("Finished sessions show up here."))
            } else {
                List {
                    ForEach(history.records) { record in
                        HistoryRow(record: record)
                            .contextMenu {
                                Button("Delete", role: .destructive) { history.delete(record) }
                            }
                    }
                    .onDelete(perform: history.delete)
                }
            }
        }
    }

    private var startOfWeek: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }
}

private struct StatTile: View {
    let title: String
    let seconds: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(formatDuration(seconds)).font(.title3.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct HistoryRow: View {
    let record: SessionRecord

    private var pomodoros: String {
        let n = record.completedPomodoros
        return record.config.mode == .flexible
            ? "\(n) pomodoro\(n == 1 ? "" : "s")"
            : "\(n)/\(record.config.totalPomodoros) pomodoros"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                Text("\(pomodoros) · \(formatDuration(record.focusSeconds)) focus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: record.finished ? "checkmark.circle.fill" : "stop.circle")
                .foregroundStyle(record.finished ? .green : .secondary)
                .help(record.finished ? "Finished" : "Stopped early")
        }
    }
}

private func formatDuration(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds) / 60
    return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
}
