import Foundation

// MARK: - Season Pass, Outbreak Alert, Vaccine Lab
//
// Season Pass: a free 30-tier pass that resets every month. Every run earns season XP; each tier
// pays coins, and every fifth tier pays Boss DNA for the Craft Lab.
// Outbreak Alert: each day one organ in the player's campaign flares up. Beating it that day pays
// a bonus once.
// Vaccine Lab: after a campaign win, a quick timing game mixes a vaccine that boosts the next run.

enum SeasonReward: Equatable {
    case coins(Int)
    case dna(Int)

    var title: String {
        switch self {
        case .coins(let n): return "\(n.formatted()) coins"
        case .dna(let n): return "\(n) Boss DNA"
        }
    }
}

enum Season {
    static let tiers = 30
    static let xpPerTier = 100

    /// Month key like "2026-11".
    static func key(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    /// "November Season" for a month key.
    static func title(_ key: String) -> String {
        let month = Int(key.split(separator: "-").last ?? "") ?? 1
        let names = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        return "\(names[max(1, min(12, month)) - 1]) Season"
    }

    /// Reward for reaching a tier (1...30).
    static func reward(tier: Int) -> SeasonReward {
        if tier == tiers { return .dna(8) }
        if tier % 10 == 0 { return .dna(4) }
        if tier % 5 == 0 { return .dna(2) }
        return .coins(100 + 10 * tier)
    }

    /// Season XP for one run: something for every run, more for long runs, bosses and wins.
    static func runXP(kills: Int, bosses: Int, seconds: Double, won: Bool) -> Int {
        min(250, 15 + kills / 25 + bosses * 20 + Int(seconds / 30) * 4 + (won ? 50 : 0))
    }
}

struct OutbreakAlert: Equatable {
    let organID: Int
    let level: Int
    static let coinBonus = 500
    static let dnaBonus = 2

    var organ: Organ { Organ.all[organID - 1].at(infection: level) }
}

extension SaveData {
    // Season Pass

    /// Starts a new season when the month changes.
    mutating func refreshSeason(now: Date = Date()) {
        let k = Season.key(now)
        if seasonKey != k { seasonKey = k; seasonXP = 0; seasonClaimed = 0 }
    }
    var seasonTier: Int { min(Season.tiers, seasonXP / Season.xpPerTier) }
    var unclaimedSeasonTiers: Int { max(0, seasonTier - seasonClaimed) }

    /// Pays every reached tier not claimed yet. Returns what was paid.
    mutating func claimSeason() -> (coins: Int, dna: Int) {
        var coins = 0, dna = 0
        guard seasonTier > seasonClaimed else { return (0, 0) }
        for t in (seasonClaimed + 1)...seasonTier {
            switch Season.reward(tier: t) {
            case .coins(let n): coins += n
            case .dna(let n): dna += n
            }
        }
        self.coins += coins
        bossDNA += dna
        seasonClaimed = seasonTier
        return (coins, dna)
    }

    // Outbreak Alert

    /// Today's alert: one organ of the active campaign the player can start now, in one of its
    /// open cities. Picked per day and country; it only moves when that organ's progress does.
    func outbreakAlert(day: String = DailyState.key(Date())) -> OutbreakAlert {
        var rng = SeededRNG(seed: (day + country.id).utf8.reduce(UInt64(77_777)) { ($0 &* 131) &+ UInt64($1) })
        let organs = Organ.all.filter { canPlay($0.id, level: 1) }
        let o = organs.randomElement(using: &rng)?.id ?? 1
        let levels = (1...unlockedInfection(o)).filter { canPlay(o, level: $0) }
        let f = Double.random(in: 0..<1, using: &rng)
        let l = levels.isEmpty ? 1 : levels[min(levels.count - 1, Int(f * Double(levels.count)))]
        return OutbreakAlert(organID: o, level: l)
    }
    func alertDone(day: String = DailyState.key(Date())) -> Bool { alertClaimedDay == day }

    /// Pays the alert bonus if this win beat `alert` (today's alert from before the run). Returns true when paid.
    mutating func claimAlert(_ organ: Organ, alert: OutbreakAlert, day: String = DailyState.key(Date())) -> Bool {
        guard !organ.isSideMode, !alertDone(day: day), alert.organID == organ.id, alert.level == organ.infection else { return false }
        alertClaimedDay = day
        coins += OutbreakAlert.coinBonus
        bossDNA += OutbreakAlert.dnaBonus
        return true
    }
}

enum VaccineLab {
    static let tries = 3
    /// Green zone center and width for each try (it gets harder).
    static let zones: [(center: Double, width: Double)] = [(0.5, 0.24), (0.28, 0.18), (0.74, 0.13)]
    /// Needle position 0...1 after `t` seconds (bounces back and forth).
    static func needle(_ t: Double) -> Double {
        let x = (t * 0.8).truncatingRemainder(dividingBy: 2)
        return x < 1 ? x : 2 - x
    }
    static func hit(_ pos: Double, try i: Int) -> Bool {
        let z = zones[max(0, min(zones.count - 1, i))]
        return abs(pos - z.center) <= z.width / 2
    }
    /// Next-run boost per vaccine star.
    static let damagePerStar = 0.08
    static let healthPerStar = 10.0
    static func boostText(_ stars: Int) -> String {
        "+\(Int(Double(stars) * damagePerStar * 100))% damage, +\(Int(Double(stars) * healthPerStar)) health next run"
    }
}
