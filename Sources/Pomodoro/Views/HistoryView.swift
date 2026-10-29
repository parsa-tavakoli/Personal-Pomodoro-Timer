import SwiftUI

/// Selected day on the History screen. An ObservableObject held by @StateObject,
/// because @State needs a SwiftUI macro plugin the Command Line Tools don't ship.
final class HistorySelection: ObservableObject {
    @Published var day = Calendar.current.startOfDay(for: Date())
    /// Monday of the week the strip shows.
    @Published private(set) var weekStart = Stats.currentWeek().first ?? Calendar.current.startOfDay(for: Date())

    var days: [Date] { Stats.week(containing: weekStart) }
    var isCurrentWeek: Bool { weekStart == Stats.currentWeek().first }

    /// Moves the strip by whole weeks; selects that week's Monday (or today on this week).
    func moveWeek(by weeks: Int) {
        guard let start = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: weekStart),
              let monday = Stats.week(containing: start).first else { return }
        let today = Calendar.current.startOfDay(for: Date())
        guard monday <= today else { return }
        weekStart = monday
        day = isCurrentWeek ? today : monday
    }

    func goToToday() {
        weekStart = Stats.currentWeek().first ?? weekStart
        day = Calendar.current.startOfDay(for: Date())
    }
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

            WeekNavigator(selection: selection)

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
                                    Menu("Project") {
                                        ProjectMenuItems(selection: Binding(
                                            get: { history.records.first { $0.id == record.id }?.projectID },
                                            set: { history.setProject(record.id, to: $0) }))
                                    }
                                    Divider()
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

    private var weekDays: [Date] { selection.days }
}

/// ‹ week range › row above the strip, with a Today button when browsing older weeks.
private struct WeekNavigator: View {
    @ObservedObject var selection: HistorySelection

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            arrow("chevron.left", label: "Previous week") { selection.moveWeek(by: -1) }
            Spacer(minLength: 0)
            Text(selection.isCurrentWeek ? "This week" : rangeText)
                .font(Theme.Fonts.body(13, .medium))
                .foregroundStyle(Theme.Palette.textMuted)
            if !selection.isCurrentWeek {
                Button("Today") { selection.goToToday() }
                    .buttonStyle(.plain)
                    .font(Theme.Fonts.body(12, .semibold))
                    .foregroundStyle(Theme.Palette.accent)
                    .padding(.leading, 4)
            }
            Spacer(minLength: 0)
            arrow("chevron.right", label: "Next week") { selection.moveWeek(by: 1) }
                .disabled(selection.isCurrentWeek)
                .opacity(selection.isCurrentWeek ? 0.3 : 1)
        }
        .frame(height: 24)
    }

    /// "20–26 Oct 2026", or "27 Oct – 2 Nov 2026" across months.
    private var rangeText: String {
        guard let first = selection.days.first, let last = selection.days.last else { return "" }
        let cal = Calendar.current
        let end = last.formatted(.dateTime.day().month(.abbreviated).year())
        if cal.isDate(first, equalTo: last, toGranularity: .month) {
            return "\(first.formatted(.dateTime.day()))–\(end)"
        }
        return "\(first.formatted(.dateTime.day().month(.abbreviated))) – \(end)"
    }

    private func arrow(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}

/// Focus swatch plus the selected day's totals.
private struct DayTotalRow: View {
    let records: [SessionRecord]

    var body: some View {
        let focus = records.reduce(0) { $0 + $1.focusSeconds }
        HStack(spacing: 6) {
            swatch(Theme.Palette.accent, "Focus")
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
    @EnvironmentObject private var projects: ProjectStore
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
                    let project = projects.project(record.projectID)
                    ForEach(0..<pipTotal, id: \.self) { i in
                        Pip(state: i < record.completedPomodoros ? .done : .upcoming,
                            color: project?.color ?? Theme.Palette.accent)
                    }
                    Text(pipLabel)
                        .font(Theme.Fonts.body(12))
                        .foregroundStyle(Theme.Palette.textMuted)
                        .padding(.leading, 3)
                    if let project {
                        ProjectTag(project: project)
                            .padding(.leading, 4)
                    }
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

/// Small coloured project label, e.g. "● Thesis".
struct ProjectTag: View {
    let project: Project

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(project.color).frame(width: 6, height: 6)
            Text(project.name)
                .lineLimit(1)
        }
        .font(Theme.Fonts.body(11))
        .foregroundStyle(Theme.Palette.textMuted)
    }
}
