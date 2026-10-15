import Foundation

enum SessionMode: String, Codable, CaseIterable {
    /// A set number of pomodoros, with breaks in between that start on their own.
    case fixed = "Fixed"
    /// Starts with one pomodoro; each timer runs into overtime until you choose what's next.
    case flexible = "Flexible"
}

/// User-editable lengths for one big session.
struct SessionConfig: Codable, Equatable {
    var mode: SessionMode = .fixed
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var pomodorosPerLongBreak = 4
    var totalPomodoros = 8

    init() {}

    // Missing keys fall back to defaults, so configs saved by older versions still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SessionConfig()
        mode = try c.decodeIfPresent(SessionMode.self, forKey: .mode) ?? d.mode
        focusMinutes = try c.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? d.focusMinutes
        shortBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? d.shortBreakMinutes
        longBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? d.longBreakMinutes
        pomodorosPerLongBreak = try c.decodeIfPresent(Int.self, forKey: .pomodorosPerLongBreak) ?? d.pomodorosPerLongBreak
        totalPomodoros = try c.decodeIfPresent(Int.self, forKey: .totalPomodoros) ?? d.totalPomodoros
    }

    func duration(of kind: Block.Kind) -> TimeInterval {
        let minutes: Int
        switch kind {
        case .focus: minutes = focusMinutes
        case .shortBreak: minutes = shortBreakMinutes
        case .longBreak: minutes = longBreakMinutes
        }
        return TimeInterval(max(1, minutes) * 60)
    }
}

/// One small timing inside a session.
struct Block: Equatable {
    enum Kind: String {
        case focus = "Focus"
        case shortBreak = "Short Break"
        case longBreak = "Long Break"
    }

    let kind: Kind
    let duration: TimeInterval
    /// 1-based pomodoro number this block belongs to.
    let pomodoro: Int
}

enum Session {
    /// Builds the ordered list of blocks: focus, break, focus, … with a long
    /// break every `pomodorosPerLongBreak` pomodoros. No break after the last one.
    /// Flexible sessions start with a single pomodoro and grow as you go.
    static func blocks(for config: SessionConfig) -> [Block] {
        if config.mode == .flexible {
            return [Block(kind: .focus, duration: config.duration(of: .focus), pomodoro: 1)]
        }
        var blocks: [Block] = []
        let total = max(1, config.totalPomodoros)
        let every = max(1, config.pomodorosPerLongBreak)
        for n in 1...total {
            blocks.append(Block(kind: .focus, duration: config.duration(of: .focus), pomodoro: n))
            guard n < total else { break }
            if n % every == 0 {
                blocks.append(Block(kind: .longBreak, duration: config.duration(of: .longBreak), pomodoro: n))
            } else {
                blocks.append(Block(kind: .shortBreak, duration: config.duration(of: .shortBreak), pomodoro: n))
            }
        }
        return blocks
    }
}

/// A finished (or stopped) session, saved to history.
struct SessionRecord: Codable, Identifiable {
    var id = UUID()
    let startedAt: Date
    let endedAt: Date
    let config: SessionConfig
    let completedPomodoros: Int
    let focusSeconds: TimeInterval
    let finished: Bool
    /// Name of the big session; empty when you didn't give one.
    var name: String = ""

    var displayName: String { name.isEmpty ? "Untitled session" : name }
}

// In an extension so the memberwise initializer is kept.
extension SessionRecord {
    // `name` may be missing in history saved by older versions.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        endedAt = try c.decode(Date.self, forKey: .endedAt)
        config = try c.decode(SessionConfig.self, forKey: .config)
        completedPomodoros = try c.decode(Int.self, forKey: .completedPomodoros)
        focusSeconds = try c.decode(TimeInterval.self, forKey: .focusSeconds)
        finished = try c.decode(Bool.self, forKey: .finished)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
    }
}
