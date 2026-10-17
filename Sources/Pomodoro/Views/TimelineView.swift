import SwiftUI

/// History "Day timeline" (design spec C): an hour grid with one bar per logged block.
/// Content, so it's flat (no glass).
struct DayTimeline: View {
    let day: Date
    /// That day's saved sessions.
    let records: [SessionRecord]

    @EnvironmentObject private var timer: SessionTimer
    @EnvironmentObject private var projects: ProjectStore
    @EnvironmentObject private var history: HistoryStore

    private let hourHeight: CGFloat = 64
    private let barInset: CGFloat = 48
    private let calendar = Calendar.current

    /// One bar on the grid.
    private struct Bar: Identifiable {
        let id: String
        let start: Date
        let end: Date
        let kind: Block.Kind
        let label: String
        /// Saved before block logging: drawn as one softer bar for the whole session.
        var approximate = false
        /// Part of the session that's running right now.
        var live = false
        /// The saved session this bar belongs to (nil while live).
        var recordID: UUID?
        var projectID: UUID?
    }

    var body: some View {
        // Redraw every 30 s so the now line and the running session keep moving.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let bars = bars(now: context.date)
            let range = hourRange(bars: bars, now: context.date)
            ScrollViewReader { scroller in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        grid(range)
                        ForEach(bars) { bar in
                            barView(bar, range: range)
                        }
                        if calendar.isDateInToday(day) {
                            nowLine(context.date, range: range)
                        }
                    }
                    .frame(height: CGFloat(range.count) * hourHeight, alignment: .top)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                }
                .scrollIndicators(.hidden)
                .onAppear { scrollToFirst(bars, scroller) }
                .onChange(of: day) { scrollToFirst(bars, scroller) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary(bars))
        }
    }

    // MARK: - Data

    private func bars(now: Date) -> [Bar] {
        var bars: [Bar] = []
        for record in records {
            let name = record.displayName
            if record.blocks.isEmpty {
                bars.append(Bar(id: "\(record.id)", start: record.startedAt, end: record.endedAt,
                                kind: .focus, label: name, approximate: true,
                                recordID: record.id, projectID: record.projectID))
            } else {
                // Break blocks saved by 1.0.4 are skipped: breaks aren't tracked any more.
                for (i, block) in record.blocks.enumerated() where block.kind == .focus {
                    bars.append(Bar(id: "\(record.id)-\(i)", start: block.start, end: block.end,
                                    kind: block.kind, label: block.kind == .focus ? name : "",
                                    recordID: record.id, projectID: record.projectID))
                }
            }
        }
        // The session in progress, if it started on this day.
        if timer.state != .idle, let started = timer.sessionStartedAt, calendar.isDate(started, inSameDayAs: day) {
            let name = timer.sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
            for (i, block) in timer.liveBlocks(now: now).enumerated() {
                bars.append(Bar(id: "live-\(i)", start: block.start, end: block.end, kind: block.kind,
                                label: block.kind == .focus ? (name.isEmpty ? "Now" : name) : "", live: true,
                                projectID: timer.projectID))
            }
        }
        return bars.sorted { $0.start < $1.start }
    }

    /// From 09:00 (or the first bar's hour, if earlier) to the end of the last bar, or now.
    private func hourRange(bars: [Bar], now: Date) -> Range<Int> {
        let dayStart = calendar.startOfDay(for: day)
        func hour(_ date: Date) -> Double { date.timeIntervalSince(dayStart) / 3600 }
        let first = bars.map { hour($0.start) }.min() ?? 9
        var last = bars.map { hour($0.end) }.max() ?? 9
        // Today: show the hour after "now" too, so the now line never sits on the bottom edge.
        if calendar.isDateInToday(day) { last = max(last, hour(now) + 1) }
        let lower = max(0, min(9, Int(first.rounded(.down))))
        // Always include the hour that contains the last moment (e.g. the now line at 16:00).
        let upper = min(24, max(lower + 3, Int(last.rounded(.down)) + 1))
        return lower..<upper
    }

    // MARK: - Drawing

    private func grid(_ range: Range<Int>) -> some View {
        VStack(spacing: 0) {
            ForEach(range, id: \.self) { hour in
                HStack(alignment: .top, spacing: 8) {
                    Text(String(format: "%02d:00", hour))
                        .font(Theme.Fonts.mono(11))
                        .foregroundStyle(Theme.Palette.textFaint)
                        .frame(width: 40, alignment: .leading)
                        .offset(y: -7)
                    Rectangle()
                        .fill(Theme.Palette.divider)
                        .frame(height: 1)
                }
                .frame(height: hourHeight, alignment: .top)
                .id(hour)
            }
        }
    }

    private func y(_ date: Date, range: Range<Int>) -> CGFloat {
        let origin = calendar.date(byAdding: .hour, value: range.lowerBound, to: calendar.startOfDay(for: day))!
        return CGFloat(date.timeIntervalSince(origin) / 3600) * hourHeight
    }

    @ViewBuilder
    private func barView(_ bar: Bar, range: Range<Int>) -> some View {
        let top = y(bar.start, range: range)
        let height = max(3, y(bar.end, range: range) - top)
        // Focus bars take their project's colour (breaks aren't drawn).
        let color = projects.project(bar.projectID)?.color ?? Theme.Palette.accent
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.bar, style: .continuous)

        ZStack(alignment: .topLeading) {
            if bar.live {
                shape.fill(color.opacity(0.18))
                shape.strokeBorder(color, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
            } else {
                shape.fill(bar.approximate ? color.opacity(0.55) : color)
            }
            if height >= 18 && !bar.label.isEmpty {
                Text(bar.label)
                    .font(Theme.Fonts.body(12, .medium))
                    .foregroundStyle(bar.live ? Theme.Palette.textPrimary : Theme.Palette.onAccent)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.top, 3)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .padding(.leading, barInset)
        .offset(y: top)
        .help(tooltip(bar))
        .contextMenu {
            if let recordID = bar.recordID {
                Menu("Project") {
                    ProjectMenuItems(selection: Binding(
                        get: { history.records.first { $0.id == recordID }?.projectID },
                        set: { history.setProject(recordID, to: $0) }))
                }
            }
        }
    }

    private func nowLine(_ now: Date, range: Range<Int>) -> some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Theme.Palette.textPrimary)
                .frame(width: 8, height: 8)
            Rectangle()
                .fill(Theme.Palette.textPrimary)
                .frame(height: 2)
        }
        .padding(.leading, barInset - 4)
        .offset(y: y(now, range: range) - 4)
        .allowsHitTesting(false)
    }

    // MARK: - Helpers

    private func tooltip(_ bar: Bar) -> String {
        let kind = "Focus"
        let time = "\(bar.start.formatted(date: .omitted, time: .shortened))–\(bar.end.formatted(date: .omitted, time: .shortened))"
        var parts = [kind, time]
        if !bar.label.isEmpty { parts.append(bar.label) }
        if let project = projects.project(bar.projectID) { parts.append(project.name) }
        if bar.approximate { parts.append("times approximate") }
        if bar.live { parts.append("in progress") }
        return parts.joined(separator: " · ")
    }

    private func scrollToFirst(_ bars: [Bar], _ scroller: ScrollViewProxy) {
        guard let first = bars.first else { return }
        let hour = calendar.component(.hour, from: first.start)
        scroller.scrollTo(hour, anchor: .top)
    }

    private func summary(_ bars: [Bar]) -> String {
        let focus = bars.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
        return "Day timeline: \(formatDuration(focus)) of focus."
    }
}
