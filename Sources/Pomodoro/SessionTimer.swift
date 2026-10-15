import AppKit
import Foundation
import UserNotifications

/// Runs one big session, stepping through its focus/break blocks.
@MainActor
final class SessionTimer: ObservableObject {
    enum State { case idle, running, paused }

    @Published var config: SessionConfig {
        didSet {
            guard config != oldValue else { return }
            Self.saveConfig(config)
            if state == .idle { reset() }
        }
    }
    @Published private(set) var blocks: [Block] = []
    @Published private(set) var index = 0
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var state: State = .idle

    private let history: HistoryStore
    private var endDate: Date?
    private var ticker: Timer?
    private var sessionStart: Date?
    private var focusSeconds: TimeInterval = 0
    private var completedPomodoros = 0

    init(history: HistoryStore) {
        self.history = history
        self.config = Self.loadConfig()
        reset()
    }

    // MARK: - Derived

    var currentBlock: Block? { blocks.indices.contains(index) ? blocks[index] : nil }

    /// 0…1 progress through the current block.
    var blockProgress: Double {
        guard let block = currentBlock, block.duration > 0 else { return 0 }
        return 1 - remaining / block.duration
    }

    var remainingText: String { Self.format(remaining) }

    var menuBarText: String {
        switch state {
        case .idle: return "🍅"
        case .running: return "\(currentBlock?.kind == .focus ? "🍅" : "☕️") \(remainingText)"
        case .paused: return "⏸ \(remainingText)"
        }
    }

    // MARK: - Controls

    func start() {
        guard state == .idle else { return resume() }
        requestNotificationPermission()
        reset()
        sessionStart = Date()
        run()
    }

    func pause() {
        guard state == .running else { return }
        tick()
        state = .paused
        endDate = nil
        ticker?.invalidate()
    }

    func resume() {
        guard state == .paused else { return }
        run()
    }

    func toggle() {
        switch state {
        case .idle: start()
        case .running: pause()
        case .paused: resume()
        }
    }

    /// Ends the current block early and moves to the next one.
    func skip() {
        guard state != .idle else { return }
        advance(completedNaturally: false)
    }

    /// Ends the whole session early and saves what was done.
    func stop() {
        guard state != .idle else { return }
        if state == .running { tick() }
        if currentBlock?.kind == .focus, let block = currentBlock {
            focusSeconds += block.duration - remaining
        }
        finish(finished: false)
    }

    // MARK: - Engine

    private func run() {
        state = .running
        endDate = Date().addingTimeInterval(remaining)
        ticker?.invalidate()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func tick() {
        guard state == .running, let endDate else { return }
        // Computed from the end date so it stays accurate across sleep.
        remaining = max(0, endDate.timeIntervalSinceNow.rounded(.up))
        if remaining <= 0 { advance(completedNaturally: true) }
    }

    private func advance(completedNaturally: Bool) {
        guard let block = currentBlock else { return }
        if block.kind == .focus {
            focusSeconds += completedNaturally ? block.duration : block.duration - remaining
            if completedNaturally { completedPomodoros += 1 }
        }

        index += 1
        guard let next = currentBlock else {
            notify(title: "Session complete 🎉", body: "\(completedPomodoros) pomodoros done.")
            finish(finished: true)
            return
        }

        if completedNaturally {
            notify(title: "\(block.kind.rawValue) finished", body: "Next: \(next.kind.rawValue) (\(Self.format(next.duration)))")
        }
        remaining = next.duration
        if state == .running { endDate = Date().addingTimeInterval(remaining) }
    }

    private func finish(finished: Bool) {
        // Ignore sessions with under a minute of focus (accidental start/stop).
        if let sessionStart, focusSeconds >= 60 {
            history.add(SessionRecord(
                startedAt: sessionStart,
                endedAt: Date(),
                config: config,
                completedPomodoros: completedPomodoros,
                focusSeconds: focusSeconds,
                finished: finished
            ))
        }
        reset()
    }

    private func reset() {
        ticker?.invalidate()
        ticker = nil
        state = .idle
        endDate = nil
        sessionStart = nil
        focusSeconds = 0
        completedPomodoros = 0
        blocks = Session.blocks(for: config)
        index = 0
        remaining = blocks.first?.duration ?? 0
    }

    // MARK: - Notifications

    /// Notifications need a real app bundle; skip them when run via `swift run`.
    private var canNotify: Bool { Bundle.main.bundleIdentifier != nil }

    private func requestNotificationPermission() {
        guard canNotify else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notify(title: String, body: String) {
        NSSound(named: "Glass")?.play()
        guard canNotify else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers

    static func format(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    private static let configKey = "sessionConfig"

    private static func loadConfig() -> SessionConfig {
        guard let data = UserDefaults.standard.data(forKey: configKey),
              let config = try? JSONDecoder().decode(SessionConfig.self, from: data) else { return SessionConfig() }
        return config
    }

    private static func saveConfig(_ config: SessionConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }
}
