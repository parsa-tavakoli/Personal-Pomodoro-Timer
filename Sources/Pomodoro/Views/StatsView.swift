import Charts
import SwiftUI

/// Daily focus chart plus totals per session name. All content, so no glass here.
struct StatsView: View {
    enum Range: Int, CaseIterable {
        case week = 7
        case month = 30

        var title: String { "\(rawValue) days" }
    }

    @EnvironmentObject private var history: HistoryStore
    // @AppStorage rather than @State (no SwiftUI macro plugin with the Command Line Tools).
    @AppStorage("statsRange") private var range: Range = .week
    @AppStorage("statsName") private var selectedKey = ""

    var body: some View {
        let days = Stats.days(range.rawValue)
        let since = days.first ?? Date()
        let names = Stats.byName(history.records, since: since)
        // Ignore a remembered name that has no sessions in this range.
        let active = names.first { $0.key == selectedKey }

        VStack(alignment: .leading, spacing: 12) {
            Picker("Range", selection: $range) {
                ForEach(Range.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if names.isEmpty {
                ContentUnavailableView("No sessions yet", systemImage: "chart.bar",
                                       description: Text("Focus time from the last \(range.rawValue) days shows up here."))
                    .frame(maxHeight: .infinity)
            } else {
                chart(Stats.daily(history.records, days: days, nameKey: active?.key))
                summary(Stats.records(history.records, since: since, nameKey: active?.key), active: active)
                nameList(names)
            }
        }
    }

    private func chart(_ daily: [DayTotal]) -> some View {
        Chart(daily) { day in
            BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value("Focus", day.seconds / 3600)
            )
            .foregroundStyle(Color.red.gradient)
            .cornerRadius(3)
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let hours = value.as(Double.self) { Text(formatDuration(hours * 3600)) }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 7)) { _ in
                AxisValueLabel(format: range == .week
                               ? .dateTime.weekday(.abbreviated)
                               : .dateTime.day().month(.abbreviated))
            }
        }
        .frame(height: 130)
        .animation(.easeInOut, value: selectedKey)
    }

    private func summary(_ records: [SessionRecord], active: NameTotal?) -> some View {
        let total = records.reduce(0) { $0 + $1.focusSeconds }
        let pomodoros = records.reduce(0) { $0 + $1.completedPomodoros }
        return HStack {
            Text("\(active.map { "\($0.displayName): " } ?? "")\(formatDuration(total)) · avg \(formatDuration(total / Double(range.rawValue)))/day · \(pomodoros) pomodoros")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            if active != nil {
                Button("Show all") { selectedKey = "" }
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
    }

    private func nameList(_ names: [NameTotal]) -> some View {
        let total = max(1, names.reduce(0) { $0 + $1.seconds })
        return ScrollView {
            VStack(spacing: 4) {
                ForEach(names) { item in
                    Button {
                        selectedKey = selectedKey == item.key ? "" : item.key
                    } label: {
                        NameRow(item: item, share: item.seconds / total, isSelected: item.key == selectedKey)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct NameRow: View {
    let item: NameTotal
    let share: Double
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.displayName)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                Spacer()
                Text(formatDuration(item.seconds))
                    .monospacedDigit()
                Text("· \(item.sessions) session\(item.sessions == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // Drawn by hand: macOS ignores .tint on a linear ProgressView.
            Capsule()
                .fill(.quaternary)
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color.red.gradient)
                            .frame(width: max(4, geo.size.width * share))
                    }
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? AnyShapeStyle(Color.red.opacity(0.12)) : AnyShapeStyle(.quaternary.opacity(0.4)),
                    in: RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .help(isSelected ? "Click to show all" : "Click to show only \(item.displayName)")
    }
}
