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
                // Let the ambient background show through; rows stay plain content.
                .scrollContentBackground(.hidden)
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
    @EnvironmentObject private var history: HistoryStore
    let record: SessionRecord

    private var name: Binding<String> {
        Binding(get: { record.name }, set: { history.rename(record.id, to: $0) })
    }

    private var pomodoros: String {
        let n = record.completedPomodoros
        return record.config.mode == .flexible
            ? "\(n) pomodoro\(n == 1 ? "" : "s")"
            : "\(n)/\(record.config.totalPomodoros) pomodoros"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                SessionNameField(text: name, placeholder: "Untitled session")
                    .help("Click to rename")
                Text("\(record.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(pomodoros) · \(formatDuration(record.focusSeconds)) focus")
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
