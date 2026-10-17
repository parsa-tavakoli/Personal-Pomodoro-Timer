import SwiftUI

/// Selected day on the History screen. An ObservableObject held by @StateObject,
/// because @State needs a SwiftUI macro plugin the Command Line Tools don't ship.
final class HistorySelection: ObservableObject {
    @Published var day = Calendar.current.startOfDay(for: Date())
}

struct HistoryView: View {
    enum Mode: String, CaseIterable {
        case timeline = "Timeline"
        case list = "List"
    }

    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var timer: SessionTimer
    @StateObject private var selection = HistorySelection()
    // @AppStorage rather than @State (no SwiftUI macro plugin with the Command Line Tools).
    @AppStorage("historyMode") private var mode: Mode = .timeline

    private let calendar = Calendar.current

    var body: some View {
        let dayRecords = history.records.filter { calendar.isDate($0.startedAt, inSameDayAs: selection.day) }

        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("History")
                    .font(Theme.Fonts.screenTitle)
                Spacer()
                Picker("View", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .tint(Theme.Palette.inactive)
            }

            WeekStrip(selection: selection)

            DayTotalRow(records: dayRecords)

            if dayRecords.isEmpty && !runningOn(selection.day) {
                Text("No sessions on this day")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Palette.textMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if mode == .timeline {
                DayTimeline(day: selection.day, records: dayRecords)
            } else {
                ScrollView {
                    VStack(spacing: Theme.Space.s) {
                        ForEach(dayRecords) { record in
                            HistoryRow(record: record)
                                .contextMenu {
                                    Button("Delete", role: .destructive) { history.delete(record) }
                                }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// A session is running that started on `day` (the timeline shows it live).
    private func runningOn(_ day: Date) -> Bool {
        guard timer.state != .idle, let started = timer.sessionStartedAt else { return false }
        return calendar.isDate(started, inSameDayAs: day)
    }
}

/// The current week, one cell per day. The dot's opacity follows that day's session count.
private struct WeekStrip: View {
    @EnvironmentObject private var history: HistoryStore
    @ObservedObject var selection: HistorySelection

    private let calendar = Calendar.current

    var body: some View {
        let days = weekDays
        let counts = days.map { day in history.records.filter { calendar.isDate($0.startedAt, inSameDayAs: day) }.count }
        let maxCount = max(1, counts.max() ?? 1)
        let today = calendar.startOfDay(for: Date())

        HStack(spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.element) { i, day in
                let selected = calendar.isDate(day, inSameDayAs: selection.day)
                let future = day > today
                Button {
                    selection.day = day
                } label: {
                    VStack(spacing: 3) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(Theme.Fonts.body(11))
                            .foregroundStyle(Theme.Palette.textMuted)
                        Text(day.formatted(.dateTime.day()))
                            .font(Theme.Fonts.body(15, .semibold))
                        Circle()
                            .fill(Theme.Palette.accent)
                            .frame(width: 6, height: 6)
                            .opacity(counts[i] == 0 ? 0 : 0.35 + 0.65 * Double(counts[i]) / Double(maxCount))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(selected ? Theme.Palette.surfaceRaised : Theme.Palette.surfaceSunken,
                                in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                            .strokeBorder(selected ? Theme.Palette.accent : Theme.Palette.divider, lineWidth: 1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(future)
                .opacity(future ? 0.4 : 1)
                .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)), \(counts[i]) sessions")
            }
        }
    }

    private var weekDays: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

/// Focus swatch plus the selected day's totals.
private struct DayTotalRow: View {
    let records: [SessionRecord]

    var body: some View {
        let focus = records.reduce(0) { $0 + $1.focusSeconds }
        HStack(spacing: 6) {
            swatch(Theme.Palette.accent, "Focus")
            swatch(Theme.Palette.breakColor, "Break")
                .padding(.leading, 6)
            Spacer()
            Text("**\(records.count)** session\(records.count == 1 ? "" : "s") · \(formatDuration(focus))")
        }
        .font(Theme.Fonts.body(12))
    }

    private func swatch(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .foregroundStyle(Theme.Palette.textMuted)
        }
    }
}

private struct HistoryRow: View {
    @EnvironmentObject private var history: HistoryStore
    let record: SessionRecord

    private var name: Binding<String> {
        Binding(get: { record.name }, set: { history.rename(record.id, to: $0) })
    }

    /// Fixed sessions show every planned pomodoro; flexible ones only the completed.
    private var pipTotal: Int {
        let planned = record.config.mode == .flexible ? record.completedPomodoros : record.config.totalPomodoros
        return min(12, max(planned, record.completedPomodoros))
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                SessionNameField(text: name, placeholder: "Untitled session")
                    .font(Theme.Fonts.body(15, .medium))
                    .lineLimit(1)
                    .help("Click to rename")
                HStack(spacing: 5) {
                    ForEach(0..<pipTotal, id: \.self) { i in
                        Pip(state: i < record.completedPomodoros ? .done : .upcoming)
                    }
                    Text(pipLabel)
                        .font(Theme.Fonts.body(12))
                        .foregroundStyle(Theme.Palette.textMuted)
                        .padding(.leading, 3)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: Theme.Space.s) {
                Text(record.startedAt.formatted(date: .omitted, time: .shortened))
                    .font(Theme.Fonts.mono(12))
                    .foregroundStyle(Theme.Palette.textMuted)
                Text(formatDuration(record.focusSeconds))
                    .font(Theme.Fonts.mono(12))
            }
        }
        .padding(.vertical, Theme.Space.m)
        .padding(.horizontal, 14)
        .background(Theme.Palette.surfaceSunken,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .strokeBorder(Theme.Palette.divider, lineWidth: 1)
        }
        .help(record.finished ? "Finished" : "Stopped early")
    }

    private var pipLabel: String {
        record.config.mode == .flexible
            ? "\(record.completedPomodoros)"
            : "\(record.completedPomodoros)/\(record.config.totalPomodoros)"
    }
}
