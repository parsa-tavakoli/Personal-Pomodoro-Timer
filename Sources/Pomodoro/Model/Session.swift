import Foundation

/// User-editable lengths for one big session.
struct SessionConfig: Codable, Equatable {
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var pomodorosPerLongBreak = 4
    var totalPomodoros = 8
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
    static func blocks(for config: SessionConfig) -> [Block] {
        var blocks: [Block] = []
        let total = max(1, config.totalPomodoros)
        let every = max(1, config.pomodorosPerLongBreak)
        for n in 1...total {
            blocks.append(Block(kind: .focus, duration: minutes(config.focusMinutes), pomodoro: n))
            guard n < total else { break }
            if n % every == 0 {
                blocks.append(Block(kind: .longBreak, duration: minutes(config.longBreakMinutes), pomodoro: n))
            } else {
                blocks.append(Block(kind: .shortBreak, duration: minutes(config.shortBreakMinutes), pomodoro: n))
            }
        }
        return blocks
    }

    private static func minutes(_ m: Int) -> TimeInterval { TimeInterval(max(1, m) * 60) }
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
}
