import Foundation

/// In-game achievements with coin rewards. Progress is read from the save, so nothing extra
/// has to be tracked for most of them. Game Center mirrors them as "vh.ach.<rawValue>".
enum Trophy: String, CaseIterable, Identifiable {
    case firstBoss, kills1k, firstCity, evolved, endless5, cities3, streak7, dailyAll,
         goldenVirus, fiveCities, mutant, endless10, kills10k, countrySaved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstBoss: return "Boss Breaker"
        case .kills1k: return "Virus Swatter"
        case .firstCity: return "City Saver"
        case .evolved: return "Evolution"
        case .endless5: return "Hold the Line"
        case .cities3: return "Outbreak Buster"
        case .streak7: return "Loyal Hunter"
        case .dailyAll: return "Daily Hero"
        case .goldenVirus: return "Gold Rush"
        case .fiveCities: return "National Hero"
        case .mutant: return "Mutant Nano"
        case .endless10: return "Unbreakable"
        case .kills10k: return "Exterminator"
        case .countrySaved: return "Virus Free"
        }
    }

    var detail: String {
        switch self {
        case .firstBoss: return "Defeat your first boss."
        case .kills1k: return "Destroy 1,000 viruses."
        case .firstCity: return "Save your first city."
        case .evolved: return "Evolve a weapon."
        case .endless5: return "Survive 5 minutes in Endless."
        case .cities3: return "Save 3 cities."
        case .streak7: return "Play 7 days in a row."
        case .dailyAll: return "Finish all daily missions 3 times."
        case .goldenVirus: return "Catch 5 Golden Viruses."
        case .fiveCities: return "Save 5 cities."
        case .mutant: return "Buy 10 Mutation Ranks."
        case .endless10: return "Survive 10 minutes in Endless."
        case .kills10k: return "Destroy 10,000 viruses."
        case .countrySaved: return "Save all 10 cities."
        }
    }

    var symbol: String {
        switch self {
        case .firstBoss: return "crown.fill"
        case .kills1k, .kills10k: return "scope"
        case .firstCity, .cities3, .fiveCities: return "building.2.fill"
        case .evolved: return "sparkles"
        case .endless5, .endless10: return "infinity"
        case .streak7: return "flame.fill"
        case .dailyAll: return "star.fill"
        case .goldenVirus: return "bitcoinsign.circle.fill"
        case .mutant: return "atom"
        case .countrySaved: return "flag.checkered"
        }
    }

    var reward: Int {
        switch self {
        case .firstBoss, .kills1k: return 200
        case .firstCity, .evolved, .endless5: return 400
        case .cities3, .streak7, .dailyAll, .goldenVirus: return 800
        case .fiveCities, .mutant, .endless10: return 1_500
        case .kills10k: return 2_000
        case .countrySaved: return 5_000
        }
    }

    /// (current, target) from the save.
    func progress(_ s: SaveData) -> (Int, Int) {
        switch self {
        case .firstBoss: return (s.clearedStages.isEmpty ? 0 : 1, 1)
        case .kills1k: return (s.totalKills, 1_000)
        case .firstCity: return (s.citiesCleared, 1)
        case .evolved: return (s.everEvolved ? 1 : 0, 1)
        case .endless5: return (Int(s.bestEndless), 300)
        case .cities3: return (s.citiesCleared, 3)
        case .streak7: return (s.bestStreak, 7)
        case .dailyAll: return (s.dailyBonuses, 3)
        case .goldenVirus: return (s.goldenCaught, 5)
        case .fiveCities: return (s.citiesCleared, 5)
        case .mutant: return (s.ranks.values.reduce(0, +), 10)
        case .endless10: return (Int(s.bestEndless), 600)
        case .kills10k: return (s.totalKills, 10_000)
        case .countrySaved: return (s.citiesCleared, Organ.maxInfection)
        }
    }

    func done(_ s: SaveData) -> Bool { let p = progress(s); return p.0 >= p.1 }
}

extension SaveData {
    /// Trophies finished but not yet collected (drives the badge on Home).
    var unclaimedTrophies: Int { Trophy.allCases.filter { $0.done(self) && !claimedTrophies.contains($0.rawValue) }.count }

    mutating func claimTrophy(_ t: Trophy) -> Int? {
        guard t.done(self), !claimedTrophies.contains(t.rawValue) else { return nil }
        claimedTrophies.insert(t.rawValue)
        coins += t.reward
        return t.reward
    }
}
