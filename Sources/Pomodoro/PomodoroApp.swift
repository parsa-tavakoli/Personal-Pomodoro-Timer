import AppKit
import SwiftUI

@main
struct PomodoroApp: App {
    @StateObject private var history: HistoryStore
    @StateObject private var timer: SessionTimer
    @StateObject private var updates = UpdateChecker()
    @StateObject private var projects = ProjectStore()
    @StateObject private var taskArchive = TaskArchive()

    init() {
        let history = HistoryStore()
        _history = StateObject(wrappedValue: history)
        _timer = StateObject(wrappedValue: SessionTimer(history: history))
        // Show a Dock icon and window even when launched as a bare executable.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("Pomodoro", id: "main") {
            ContentView()
                .environmentObject(timer)
                .environmentObject(history)
                .environmentObject(updates)
                .environmentObject(projects)
                .environmentObject(taskArchive)
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarMenu()
                .environmentObject(timer)
                .environmentObject(updates)
        } label: {
            MenuBarLabel(clock: timer.clock)
                .environmentObject(timer)
        }

        Settings {
            SettingsView()
                .environmentObject(timer)
                .environmentObject(projects)
                .environmentObject(history)
                .environmentObject(taskArchive)
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    enum Page: String, CaseIterable {
        case timer = "Timer"
        case history = "History"
        case stats = "Stats"

        var symbol: String {
            switch self {
            case .timer: return "timer"
            case .history: return "calendar"
            case .stats: return "chart.bar"
            }
        }
    }

    @AppStorage("selectedPage") private var page: Page = .timer

    var body: some View {
        // All pages stay alive and only their visibility changes, so a click on the
        // picker never builds a page (e.g. the Stats chart) while its glass animates.
        ZStack {
            page(.timer) { TimerView() }
            page(.history) { HistoryView() }
            page(.stats) { StatsView() }
        }
        .animation(.easeInOut(duration: 0.2), value: page)
        .padding(.horizontal, Theme.Space.screen)
        .padding(.vertical, Theme.Space.m)
        .frame(width: 380, height: 460)
        .foregroundStyle(Theme.Palette.textPrimary)
        .font(Theme.Fonts.body(13))
        // Flat ink background (design spec); glass stays on the controls only.
        .background(Theme.Palette.background)
        .toolbar {
            // Toolbar items get Liquid Glass automatically.
            ToolbarItem(placement: .principal) {
                PagePicker()
            }
            ToolbarItem(placement: .primaryAction) {
                SettingsLink {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Timer settings")
                .help("Timer settings")
            }
        }
        .toolbar(removing: .title)
    }

    private func page<Content: View>(_ which: Page, @ViewBuilder content: () -> Content) -> some View {
        let visible = page == which
        return content()
            .environment(\.isVisiblePage, visible)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
    }
}

private struct VisiblePageKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// False for pages kept alive behind the visible one (their keyboard shortcuts stay off).
    var isVisiblePage: Bool {
        get { self[VisiblePageKey.self] }
        set { self[VisiblePageKey.self] = newValue }
    }
}

/// The toolbar's glass page switcher, kept as its own view so the toolbar item
/// isn't rebuilt each time the page changes.
private struct PagePicker: View {
    @AppStorage("selectedPage") private var page: ContentView.Page = .timer

    var body: some View {
        Picker("Page", selection: $page) {
            ForEach(ContentView.Page.allCases, id: \.self) { page in
                Label(page.rawValue, systemImage: page.symbol).tag(page)
            }
        }
        .pickerStyle(.segmented)
        .labelStyle(.titleAndIcon)
        .tint(Theme.Palette.accent)
    }
}

/// Menu bar time. Observes only the clock, which changes every tick.
private struct MenuBarLabel: View {
    @EnvironmentObject private var timer: SessionTimer
    @ObservedObject var clock: TimerClock

    var body: some View {
        Text(timer.menuBarText)
    }
}

struct MenuBarMenu: View {
    @EnvironmentObject private var timer: SessionTimer
    @EnvironmentObject private var updates: UpdateChecker
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let block = timer.currentBlock, timer.state != .idle {
            let name = timer.sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
            Text("\(name.isEmpty ? "" : name + " · ")\(block.kind.rawValue)\(timer.isInOvertime ? " · Overtime" : "") · \(timer.progressText)")
            Divider()
        }
        Button(timer.state == .running ? "Pause" : (timer.state == .paused ? "Resume" : "Start Session")) {
            timer.toggle()
        }
        .disabled(timer.isInOvertime)
        Button("Skip Block") { timer.skip() }
            .disabled(timer.state == .idle || timer.isInOvertime)
        Button("Stop Session") { timer.stop() }
            .disabled(timer.state == .idle)
        Divider()
        Button("Open Pomodoro…") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink { Text("Settings…") }
        if let update = updates.available {
            Button("Download Pomodoro \(update.version)…") { openURL(update.url) }
        }
        Divider()
        Button("Quit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
