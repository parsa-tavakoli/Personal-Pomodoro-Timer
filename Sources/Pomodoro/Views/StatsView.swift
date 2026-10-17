import Charts
import SwiftUI

/// Weekly stats (design spec, screen D). Content is flat; only the range toggle is glass.
struct StatsView: View {
    enum Range: Int, CaseIterable {
        case week = 7
        case month = 30

        var title: String { self == .week ? "Week" : "Month" }
    }

    /// Daily pomodoro goal shown on the chart. Fixed for now.
    static let goal = 8
    private static let hours = 0..<24

    @EnvironmentObject private var history: HistoryStore
    // @AppStorage rather than @State (no SwiftUI macro plugin with the Command Line Tools).
    @AppStorage("statsRange") private var range: Range = .week
    @AppStorage("statsName") private var selectedKey = ""

    var body: some View {
        // Week = this calendar week, Monday first; Month = the last 30 days.
        let days = range == .week ? Stats.currentWeek() : Stats.days(range.rawValue)
        let since = days.first ?? Date()
        let names = Stats.byName(history.records, since: since)
        // Ignore a remembered name that has no sessions in this range.
        let active = names.first { $0.key == selectedKey }
        let records = Stats.records(history.records, since: since, nameKey: active?.key)

        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack {
                Text("Stats")
                    .font(Theme.Fonts.screenTitle)
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(Range.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                // Spec: neutral selected segment rather than the system blue.
                .tint(Theme.Palette.inactive)
            }

            if names.isEmpty {
                Text(range == .week ? "No sessions this week" : "No sessions in the last 30 days")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Palette.textMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        kpis(records)
                        if let active {
                            filterBanner(active)
                        }
                        card("Pomodoros per day") {
                            chart(Stats.daily(history.records, days: days, nameKey: active?.key))
                        }
                        card("Most focused hours") {
                            hoursRow(Stats.focusByHour(history.records, since: since,
                                                        nameKey: active?.key, hours: Self.hours))
                        }
                        card("By task") {
                            nameList(names)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - KPI tiles

    private func kpis(_ records: [SessionRecord]) -> some View {
        let focus = records.reduce(0) { $0 + $1.focusSeconds }
        let streak = Stats.streak(history.records)
        return HStack(spacing: Theme.Space.s) {
            KPITile(label: "Focus time", value: formatDuration(focus))
            KPITile(label: "Sessions", value: "\(records.count)")
            KPITile(label: "Streak", value: "\(streak) day\(streak == 1 ? "" : "s")")
        }
    }

    private func filterBanner(_ active: NameTotal) -> some View {
        HStack {
            Circle().fill(Theme.Palette.accent).frame(width: 8, height: 8)
            Text("Showing \(active.displayName)")
                .lineLimit(1)
            Spacer()
            Button("Show all") { selectedKey = "" }
                .buttonStyle(.link)
                .tint(Theme.Palette.accent)
        }
        .font(Theme.Fonts.body(12))
    }

    // MARK: - Cards

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text(title)
                .font(Theme.Fonts.body(13, .semibold))
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: Theme.Radius.card)
    }

    private func chart(_ daily: [DayTotal]) -> some View {
        let today = Calendar.current.startOfDay(for: Date())
        let maxValue = max(Self.goal + 1, daily.map(\.pomodoros).max() ?? 0)
        return Chart {
            ForEach(daily) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Pomodoros", day.pomodoros)
                )
                .foregroundStyle(Theme.Palette.accent.opacity(day.date == today ? 1 : 0.55))
                .cornerRadius(3)
                .annotation(position: .top, spacing: 2) {
                    if range == .week && day.pomodoros > 0 {
                        Text("\(day.pomodoros)")
                            .font(Theme.Fonts.mono(11))
                            .foregroundStyle(Theme.Palette.textMuted)
                    }
                }
            }
            RuleMark(y: .value("Goal", Self.goal))
                .foregroundStyle(Theme.Palette.textFaint)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("Goal \(Self.goal)")
                        .font(Theme.Fonts.mono(11))
                        .foregroundStyle(Theme.Palette.textFaint)
                }
        }
        .chartYScale(domain: 0...maxValue)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 7)) { _ in
                AxisValueLabel(format: range == .week
                               ? .dateTime.weekday(.narrow)
                               : .dateTime.day())
                    .font(Theme.Fonts.mono(11))
                    .foregroundStyle(Theme.Palette.textFaint)
            }
        }
        .frame(height: 120)
        .accessibilityLabel(chartSummary(daily))
    }

    private func chartSummary(_ daily: [DayTotal]) -> String {
        let total = daily.reduce(0) { $0 + $1.pomodoros }
        let best = daily.max { $0.pomodoros < $1.pomodoros }
        let bestText = best.map { " Best day \($0.date.formatted(.dateTime.weekday(.wide))) with \($0.pomodoros)." } ?? ""
        return "Pomodoros per day: \(total) over \(daily.count) days, goal \(Self.goal) a day.\(bestText)"
    }

    private func hoursRow(_ seconds: [TimeInterval]) -> some View {
        let most = max(1, seconds.max() ?? 1)
        return VStack(alignment: .leading, spacing: 6) {
            // All 24 hours; cells are thin, so each one names its hour on hover.
            HStack(spacing: 2) {
                ForEach(Array(seconds.enumerated()), id: \.offset) { i, focus in
                    let hour = Self.hours.lowerBound + i
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(focus < 60
                              ? Theme.Palette.divider
                              : Theme.Palette.accent.opacity(0.2 + 0.8 * focus / most))
                        .frame(height: 32)
                        .help(String(format: "%02d:00–%02d:00 · ", hour, hour + 1)
                              + (focus < 60 ? "no focus" : "\(formatDuration(focus)) focus"))
                }
            }
            HStack {
                Text("00:00")
                Spacer()
                Text("06:00")
                Spacer()
                Text("12:00")
                Spacer()
                Text("18:00")
                Spacer()
                Text("24:00")
            }
            .font(Theme.Fonts.mono(11))
            .foregroundStyle(Theme.Palette.textFaint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Most focused hours: \(busiestHour(seconds))")
    }

    private func busiestHour(_ seconds: [TimeInterval]) -> String {
        guard let i = seconds.indices.max(by: { seconds[$0] < seconds[$1] }), seconds[i] >= 60 else { return "no focus yet" }
        return String(format: "%02d:00, ", Self.hours.lowerBound + i) + "\(formatDuration(seconds[i])) of focus"
    }

    private func nameList(_ names: [NameTotal]) -> some View {
        let top = max(1, names.first?.seconds ?? 1)
        return VStack(spacing: Theme.Space.s) {
            ForEach(names) { item in
                Button {
                    selectedKey = selectedKey == item.key ? "" : item.key
                } label: {
                    TaskBar(item: item, share: item.seconds / top, isSelected: item.key == selectedKey)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct KPITile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Theme.Fonts.body(12))
                .foregroundStyle(Theme.Palette.textMuted)
            Text(value)
                .font(Theme.Fonts.statValue)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, Theme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: Theme.Radius.row)
    }
}

/// "By task" row: name, a bar scaled to the top task, and its time.
private struct TaskBar: View {
    let item: NameTotal
    let share: Double
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Text(item.displayName)
                .font(Theme.Fonts.body(12, isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Theme.Palette.textPrimary : Theme.Palette.textMuted)
                .lineLimit(1)
                .frame(width: 96, alignment: .leading)
            Capsule()
                .fill(Theme.Palette.stroke)
                .frame(height: 8)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(Theme.Palette.accent)
                            .frame(width: max(8, geo.size.width * share))
                    }
                }
            Text(formatDuration(item.seconds))
                .font(Theme.Fonts.mono(12))
                .frame(width: 56, alignment: .trailing)
        }
        .frame(minHeight: 22)
        .contentShape(Rectangle())
        .help(isSelected ? "Click to show all" : "Click to show only \(item.displayName)")
    }
}
