import Foundation

// MARK: - Daily missions and login streak
//
// Every day: three missions picked from a pool (same for everyone on that date), a bonus for
// finishing all three, and a login streak reward that grows for 7 days in a row.

enum MissionKind: String, Codable, CaseIterable {
    case kills, bosses, organClears, survive, coins, reachLevel, endless

    func title(_ target: Int) -> String {
        switch self {
        case .kills: return "Destroy \(target.formatted()) viruses"
        case .bosses: return target == 1 ? "Defeat a boss" : "Defeat \(target) bosses"
        case .organClears: return target == 1 ? "Clear an organ" : "Clear \(target) organs"
        case .survive: return "Survive \(clock(target)) in one run"
        case .coins: return "Pick up \(target) coins in runs"
        case .reachLevel: return "Reach level \(target) in one run"
        case .endless: return "Last \(clock(target)) in Endless"
        }
    }

    var symbol: String {
        switch self {
        case .kills: return "scope"
        case .bosses: return "crown.fill"
        case .organClears: return "checkmark.seal.fill"
        case .survive: return "clock.fill"
        case .coins: return "bitcoinsign.circle.fill"
        case .reachLevel: return "arrow.up.circle.fill"
        case .endless: return "infinity"
        }
    }

    /// Possible targets, easy to hard, and the coin reward for each.
    var tiers: [(target: Int, reward: Int)] {
        switch self {
        case .kills: return [(400, 250), (900, 400), (1_600, 600)]
        case .bosses: return [(1, 250), (2, 400), (3, 600)]
        case .organClears: return [(1, 250), (2, 400), (3, 600)]
        case .survive: return [(180, 250), (240, 400), (300, 600)]
        case .coins: return [(40, 250), (80, 400), (140, 600)]
        case .reachLevel: return [(15, 250), (22, 400), (30, 600)]
        case .endless: return [(180, 300), (300, 450), (480, 700)]
        }
    }

    /// "Best in one run" missions track a maximum instead of adding up.
    var isBest: Bool { self == .survive || self == .reachLevel || self == .endless }

    private func clock(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
}

struct Mission: Codable, Equatable, Identifiable {
    var id: Int
    var kind: MissionKind
    var target: Int
    var reward: Int
    var progress: Int = 0
    var claimed = false

    var done: Bool { progress >= target }
    var title: String { kind.title(target) }
    var fraction: Double { min(1, Double(progress) / Double(max(1, target))) }
}

/// What a finished run reports to the daily missions.
struct RunReport {
    var kills = 0
    var bosses = 0
    var cleared = false
    var seconds = 0.0
    var coins = 0
    var level = 1
    var endless = false
}

struct DailyState: Codable, Equatable {
    var day = ""                 // yyyy-MM-dd the missions belong to
    var missions: [Mission] = []
    var bonusClaimed = false
    var streak = 0               // days in a row the game was opened
    var lastLoginDay = ""
    var streakClaimedDay = ""

    static let bonusReward = 500
    /// Login reward by streak day (day 7 and later pay the top amount).
    static let streakRewards = [100, 150, 200, 300, 400, 500, 1_000]

    var streakReward: Int { DailyState.streakRewards[max(0, min(DailyState.streakRewards.count - 1, streak - 1))] }
    var canClaimStreak: Bool { streak > 0 && streakClaimedDay != lastLoginDay }
    var allDone: Bool { !missions.isEmpty && missions.allSatisfy(\.done) }
    var canClaimBonus: Bool { allDone && !bonusClaimed }
    /// Rewards waiting to be collected (drives the badge on Home).
    var unclaimed: Int { missions.filter { $0.done && !$0.claimed }.count + (canClaimBonus ? 1 : 0) + (canClaimStreak ? 1 : 0) }

    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Rolls over to a new day: new missions, and the login streak grows or resets.
    mutating func refresh(now: Date = Date(), calendar: Calendar = .current) {
        let today = DailyState.key(now, calendar: calendar)
        if day != today {
            day = today
            missions = DailyState.missions(for: today)
            bonusClaimed = false
        }
        if lastLoginDay != today {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now).map { DailyState.key($0, calendar: calendar) }
            streak = lastLoginDay == yesterday ? streak + 1 : 1
            lastLoginDay = today
        }
    }

    /// Three missions of different kinds, picked from the date so everyone gets the same set that day.
    static func missions(for day: String) -> [Mission] {
        var rng = SeededRNG(seed: day.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) })
        var kinds = MissionKind.allCases
        var out: [Mission] = []
        for i in 0..<3 {
            let k = kinds.remove(at: Int.random(in: 0..<kinds.count, using: &rng))
            // One easy, one medium, one hard mission each day.
            let t = k.tiers[i]
            out.append(Mission(id: i, kind: k, target: t.target, reward: t.reward))
        }
        return out
    }

    mutating func record(_ r: RunReport) {
        for i in missions.indices where !missions[i].claimed {
            let add: Int
            switch missions[i].kind {
            case .kills: add = r.kills
            case .bosses: add = r.bosses
            case .organClears: add = r.cleared ? 1 : 0
            case .coins: add = r.coins
            case .survive: missions[i].progress = max(missions[i].progress, Int(r.seconds)); continue
            case .reachLevel: missions[i].progress = max(missions[i].progress, r.level); continue
            case .endless: if r.endless { missions[i].progress = max(missions[i].progress, Int(r.seconds)) }; continue
            }
            missions[i].progress = min(missions[i].target, missions[i].progress + add)
        }
    }
}

/// Small deterministic generator (SplitMix64) so daily missions match across devices.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

extension SaveData {
    /// Claims a finished mission's coins.
    mutating func claimMission(_ id: Int) -> Int? {
        guard let i = daily.missions.firstIndex(where: { $0.id == id }), daily.missions[i].done, !daily.missions[i].claimed else { return nil }
        daily.missions[i].claimed = true
        coins += daily.missions[i].reward
        return daily.missions[i].reward
    }

    mutating func claimDailyBonus() -> Int? {
        guard daily.canClaimBonus else { return nil }
        daily.bonusClaimed = true
        dailyBonuses += 1
        coins += DailyState.bonusReward
        return DailyState.bonusReward
    }

    mutating func claimStreak() -> Int? {
        guard daily.canClaimStreak else { return nil }
        daily.streakClaimedDay = daily.lastLoginDay
        bestStreak = max(bestStreak, daily.streak)
        coins += daily.streakReward
        return daily.streakReward
    }
}
