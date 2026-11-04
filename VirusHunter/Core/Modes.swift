import Foundation

// MARK: - Special missions

/// From the second city on, some organs are a different kind of mission.
enum RunMode: String, CaseIterable {
    case normal, defense, escape

    var title: String {
        switch self {
        case .normal: return "Clear the Organ"
        case .defense: return "Hospital Defense"
        case .escape: return "Escape"
        }
    }
    var detail: String {
        switch self {
        case .normal: return "Survive and beat the boss."
        case .defense: return "Protect Patient Zero's bed until the boss shows up, then beat it."
        case .escape: return "The organ is collapsing! Fly to the exit before the viruses catch you."
        }
    }
    var symbol: String {
        switch self {
        case .normal: return "scope"
        case .defense: return "cross.case.fill"
        case .escape: return "figure.run"
        }
    }
    /// Seconds until the boss in Hospital Defense (it comes sooner than usual).
    static let defenseBossTime = 150.0
    /// How far the exit is in Escape.
    static let escapeDistance = 2_400.0
}

extension Organ {
    /// City 1 and Endless are always normal. From city 2, one organ per city is Hospital Defense,
    /// and from city 3 another is Escape (King Vex's final fight stays normal).
    func mode(country: String) -> RunMode {
        guard !isEndless, !isBossRush, infection >= 2, finalBoss != .bossVex else { return .normal }
        var rng = SeededRNG(seed: country.utf8.reduce(UInt64(77_017) &+ UInt64(infection) &* 613) { ($0 &* 131) &+ UInt64($1) })
        let order = [1, 2, 3, 4, 5].shuffled(using: &rng)
        if id == order[0] { return .defense }
        if id == order[1], infection >= 3 { return .escape }
        return .normal
    }
}

// MARK: - Weekly Boss Rush

enum BossRush {
    static let bosses = 5
    static let firstWinReward = 400
    static let replayReward = 100

    /// Week key like "2026-W45" (ISO weeks, so everyone shares the same lineup).
    static func week(_ date: Date = Date()) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", c.yearForWeekOfYear ?? 0, c.weekOfYear ?? 0)
    }

    /// This week's five bosses: every organ boss once, each with a variant (the last one is Mega or Shadow).
    static func lineup(week: String) -> [BossSetup] {
        var rng = SeededRNG(seed: week.utf8.reduce(UInt64(424_242)) { ($0 &* 33) &+ UInt64($1) })
        let kinds = EnemyKind.bossRoster.shuffled(using: &rng)
        let variants = BossVariant.twists.shuffled(using: &rng)
        return kinds.enumerated().map { BossSetup(kind: $0.element, variant: variants[$0.offset]) }
    }
}

extension SaveData {
    var bossRushUnlocked: Bool { citiesCleared >= 1 }
    /// Best Boss Rush time this week (nil = not beaten yet).
    func bossRushBest(week: String = BossRush.week()) -> Double? { bossRushBests[week] }
}

// MARK: - Kill combos

enum Combo {
    /// Seconds between kills that keep a combo alive.
    static let window = 1.5
    /// Combo milestones and their coin reward.
    static let rewards: [(count: Int, coins: Int)] = [(25, 5), (50, 10), (100, 20), (200, 40), (400, 80)]
    static func reward(at count: Int) -> Int? { rewards.first { $0.count == count }?.coins }
}
