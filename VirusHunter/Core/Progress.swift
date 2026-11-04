import Foundation

/// Permanent upgrades bought with Bio-Coins in the Tech Lab.
enum TechKind: String, CaseIterable, Codable, Identifiable {
    case power, armor, health, speed, magnet, greed, revive
    var id: String { rawValue }
    var title: String {
        switch self {
        case .power: return "Power Core"
        case .armor: return "Hull Plating"
        case .health: return "Vital Cells"
        case .speed: return "Thrusters"
        case .magnet: return "Collector"
        case .greed: return "Coin Scanner"
        case .revive: return "Backup Chip"
        }
    }
    var symbol: String {
        switch self {
        case .power: return "flame.fill"
        case .armor: return "shield.fill"
        case .health: return "heart.fill"
        case .speed: return "hare.fill"
        case .magnet: return "dot.circle.and.hand.point.up.left.fill"
        case .greed: return "bitcoinsign.circle.fill"
        case .revive: return "arrow.counterclockwise.circle.fill"
        }
    }
    var maxLevel: Int { self == .revive ? 1 : 10 }
    /// Mutation Ranks: smaller upgrades bought after a tech is MAX, so coins always have a use.
    var maxRank: Int { self == .revive ? 0 : 50 }
    /// How much one Mutation Rank is worth compared with one regular level.
    var rankWeight: Double { self == .speed ? 0.2 : 0.4 }
    func rankCost(toRank r: Int) -> Int { 2000 + 400 * (r - 1) }
    func effect(_ level: Int, rank: Int = 0) -> String {
        let v = Double(level) + rankWeight * Double(rank)
        func n(_ x: Double) -> String { x == x.rounded() ? "\(Int(x))" : String(format: "%.1f", x) }
        switch self {
        case .power: return "+\(n(v * 5))% damage"
        case .armor: return "−\(n(min(50, v * 3)))% damage taken"
        case .health: return "+\(n(v * 10)) max health"
        case .speed: return "+\(n(v * 3))% speed"
        case .magnet: return "+\(n(v * 8))% pickup range"
        case .greed: return "+\(n(v * 8))% Bio-Coins"
        case .revive: return level > 0 ? "One free revive per run" : "Revive once per run for free"
        }
    }
    func cost(toLevel l: Int) -> Int {
        if self == .revive { return 1500 }
        return Int(60 * pow(1.45, Double(l - 1)))
    }
}

/// Everything saved on the device.
struct SaveData: Codable, Equatable {
    var coins: Int = 0
    var unlockedStage: Int = 1          // highest playable organ
    var clearedStages: Set<Int> = []
    var bestEndless: Double = 0          // seconds
    var tech: [String: Int] = [:]
    var runs: Int = 0
    var totalKills: Int = 0
    var soundOn: Bool = true
    var hapticsOn: Bool = true
    var seenIntro: Bool = false
    var ownedSkins: Set<String> = []
    var skinID: String = Skin.classic.rawValue
    var ranks: [String: Int] = [:]              // Mutation Ranks bought after a tech is MAX
    var infectionCleared: [String: Int] = [:]   // organ id -> highest Infection Level cleared
    var seenStory: Set<String> = []             // story scene ids already shown
    var countryCode: String?                    // chosen outbreak country (nil = not asked yet)
    var daily = DailyState()                    // daily missions + login streak
    var everEvolved = false                     // evolved a weapon at least once (achievement)
    var claimedTrophies: Set<String> = []
    var bestStreak = 0                          // longest login streak
    var dailyBonuses = 0                        // times all three daily missions were finished
    var goldenCaught = 0                        // Golden Viruses caught
    var discovered: Set<String> = []            // Virus-pedia cards unlocked (texture names)
    var ownedAllies: Set<String> = []           // recruited allies
    var allyID: String?                         // ally flying with Nano
    var bossRushBests: [String: Double] = [:]   // week -> best Boss Rush time
    var bestCombo = 0
    /// Each country is its own campaign: organ -> Infection Level cleared, for the countries not
    /// active right now (the active country's progress lives in `infectionCleared`).
    var countryProgress: [String: [String: Int]] = [:]
    /// Most cities ever saved in one country (city rewards, allies and Boss Rush stay unlocked).
    var bestCities = 0
    var bossDNA = 0                             // crafting material from bosses
    var crafted: Set<String> = []               // weapons crafted in the Craft Lab

    func level(_ t: TechKind) -> Int { tech[t.rawValue] ?? 0 }
    func rank(_ t: TechKind) -> Int { ranks[t.rawValue] ?? 0 }
    /// Level plus Mutation Ranks, in regular-level units, used for stats.
    func power(_ t: TechKind) -> Double { Double(level(t)) + t.rankWeight * Double(rank(t)) }

    /// Price of the next purchase for this tech: a level, then a Mutation Rank, nil when fully maxed.
    func nextCost(_ t: TechKind) -> Int? {
        let l = level(t)
        if l < t.maxLevel { return t.cost(toLevel: l + 1) }
        let r = rank(t)
        return r < t.maxRank ? t.rankCost(toRank: r + 1) : nil
    }

    mutating func buy(_ t: TechKind) -> Bool {
        guard let c = nextCost(t), coins >= c else { return false }
        coins -= c
        let l = level(t)
        if l < t.maxLevel { tech[t.rawValue] = l + 1 } else { ranks[t.rawValue] = rank(t) + 1 }
        return true
    }

    /// Highest Infection Level cleared for an organ (0 = never cleared).
    func clearedInfection(_ organID: Int) -> Int { infectionCleared[String(organID)] ?? 0 }
    /// Highest Infection Level (city) the player may start for an organ: one above what it has cleared,
    /// but never past the active city (every organ must be cleared in a city before the next opens).
    func unlockedInfection(_ organID: Int) -> Int {
        max(1, min(Organ.maxInfection, clearedInfection(organID) + 1, citiesCleared + 1))
    }

    mutating func recordClear(_ o: Organ) {
        guard !o.isSideMode else { return }
        clearedStages.insert(o.id)
        unlockedStage = max(unlockedStage, min(5, o.id + 1))
        infectionCleared[String(o.id)] = max(clearedInfection(o.id), o.infection)
        bestCities = max(bestCities, citiesCleared)
    }

    /// Moves to another country's campaign: the current one is put away, the new one starts fresh
    /// (or where the player left it). Upgrades, coins, skins and unlocks stay.
    mutating func switchCountry(to code: String) {
        guard code != countryCode else { return }
        if let old = countryCode { countryProgress[old] = infectionCleared }
        else if !infectionCleared.isEmpty { countryProgress[code] = infectionCleared } // first pick keeps what was played
        infectionCleared = countryProgress.removeValue(forKey: code) ?? [:]
        countryCode = code
        // City story scenes play again with the new city names.
        seenStory = seenStory.filter { !($0.hasPrefix("city-") || $0.hasPrefix("vaccine-") || $0 == "clear-1" || $0 == "finale") }
    }

    /// Cities saved in one country's campaign.
    func citiesSaved(in code: String) -> Int {
        if code == countryCode { return citiesCleared }
        guard let p = countryProgress[code] else { return 0 }
        return Organ.all.map { p[String($0.id)] ?? 0 }.min() ?? 0
    }

    /// Cities saved in every country together (leaderboard).
    var citiesSavedEverywhere: Int {
        countryProgress.values.reduce(citiesCleared) { total, p in
            total + (Organ.all.map { p[String($0.id)] ?? 0 }.min() ?? 0)
        }
    }

    /// Countries whose ten cities are all saved.
    var countriesSaved: Int {
        countryProgress.values.filter { p in Organ.all.allSatisfy { (p[String($0.id)] ?? 0) >= Organ.maxInfection } }.count
            + (citiesCleared >= Organ.maxInfection ? 1 : 0)
    }

    var endlessUnlocked: Bool { clearedStages.contains(2) }
}

extension SaveData {
    /// Missing keys fall back to defaults, so saves from older versions keep their progress.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SaveData()
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? d.coins
        unlockedStage = try c.decodeIfPresent(Int.self, forKey: .unlockedStage) ?? d.unlockedStage
        clearedStages = try c.decodeIfPresent(Set<Int>.self, forKey: .clearedStages) ?? d.clearedStages
        bestEndless = try c.decodeIfPresent(Double.self, forKey: .bestEndless) ?? d.bestEndless
        tech = try c.decodeIfPresent([String: Int].self, forKey: .tech) ?? d.tech
        runs = try c.decodeIfPresent(Int.self, forKey: .runs) ?? d.runs
        totalKills = try c.decodeIfPresent(Int.self, forKey: .totalKills) ?? d.totalKills
        soundOn = try c.decodeIfPresent(Bool.self, forKey: .soundOn) ?? d.soundOn
        hapticsOn = try c.decodeIfPresent(Bool.self, forKey: .hapticsOn) ?? d.hapticsOn
        seenIntro = try c.decodeIfPresent(Bool.self, forKey: .seenIntro) ?? d.seenIntro
        ownedSkins = try c.decodeIfPresent(Set<String>.self, forKey: .ownedSkins) ?? d.ownedSkins
        skinID = try c.decodeIfPresent(String.self, forKey: .skinID) ?? d.skinID
        ranks = try c.decodeIfPresent([String: Int].self, forKey: .ranks) ?? d.ranks
        infectionCleared = try c.decodeIfPresent([String: Int].self, forKey: .infectionCleared) ?? d.infectionCleared
        seenStory = try c.decodeIfPresent(Set<String>.self, forKey: .seenStory) ?? d.seenStory
        countryCode = try c.decodeIfPresent(String.self, forKey: .countryCode)
        daily = try c.decodeIfPresent(DailyState.self, forKey: .daily) ?? d.daily
        everEvolved = try c.decodeIfPresent(Bool.self, forKey: .everEvolved) ?? d.everEvolved
        claimedTrophies = try c.decodeIfPresent(Set<String>.self, forKey: .claimedTrophies) ?? d.claimedTrophies
        bestStreak = try c.decodeIfPresent(Int.self, forKey: .bestStreak) ?? d.bestStreak
        dailyBonuses = try c.decodeIfPresent(Int.self, forKey: .dailyBonuses) ?? d.dailyBonuses
        goldenCaught = try c.decodeIfPresent(Int.self, forKey: .goldenCaught) ?? d.goldenCaught
        discovered = try c.decodeIfPresent(Set<String>.self, forKey: .discovered) ?? d.discovered
        ownedAllies = try c.decodeIfPresent(Set<String>.self, forKey: .ownedAllies) ?? d.ownedAllies
        allyID = try c.decodeIfPresent(String.self, forKey: .allyID)
        bossRushBests = try c.decodeIfPresent([String: Double].self, forKey: .bossRushBests) ?? d.bossRushBests
        bestCombo = try c.decodeIfPresent(Int.self, forKey: .bestCombo) ?? d.bestCombo
        countryProgress = try c.decodeIfPresent([String: [String: Int]].self, forKey: .countryProgress) ?? d.countryProgress
        // Older saves only knew clearedStages: those count as the first city of the current country.
        for id in clearedStages where (infectionCleared[String(id)] ?? 0) < 1 { infectionCleared[String(id)] = 1 }
        bestCities = try c.decodeIfPresent(Int.self, forKey: .bestCities) ?? d.bestCities
        bossDNA = try c.decodeIfPresent(Int.self, forKey: .bossDNA) ?? d.bossDNA
        crafted = try c.decodeIfPresent(Set<String>.self, forKey: .crafted) ?? d.crafted
        bestCities = max(bestCities, citiesCleared)
    }
}

/// Player numbers for a run: Tech Lab + in-run passives.
struct PlayerStats: Equatable {
    var maxHP: Double
    var speed: Double
    var magnet: Double
    var damage: Double   // multiplier
    var cooldown: Double // multiplier (< 1 is faster)
    var armor: Double    // fraction of damage blocked
    var regen: Double    // hp / s
    var coinBonus: Double

    /// Points per second with no upgrades. Must comfortably outrun regular viruses from the first second.
    static let baseSpeed: Double = 210

    static func make(save: SaveData, loadout: Loadout) -> PlayerStats {
        let p = loadout.passives
        return PlayerStats(
            maxHP: 100 + save.power(.health) * 10 + Double((p[.maxHP] ?? 0) * 20),
            speed: PlayerStats.baseSpeed * (1 + 0.03 * save.power(.speed) + 0.08 * Double(p[.speed] ?? 0)),
            magnet: 120 * (1 + 0.08 * save.power(.magnet) + 0.30 * Double(p[.magnet] ?? 0)),
            damage: 1 + 0.05 * save.power(.power) + 0.10 * Double(p[.power] ?? 0),
            cooldown: max(0.5, 1 - 0.08 * Double(p[.rapid] ?? 0)),
            armor: min(0.5, 0.03 * save.power(.armor)),
            regen: 0.6 * Double(p[.regen] ?? 0),
            coinBonus: 1 + 0.08 * save.power(.greed)
        )
    }
}

/// Weapon numbers per level (index 0 = level 1, index 5 = evolved).
enum WeaponStats {
    static func laser(_ l: Int) -> (cooldown: Double, damage: Double, bolts: Int, pierce: Int) {
        let i = max(0, min(evolvedLevel - 1, l - 1))
        return ([0.85, 0.78, 0.7, 0.64, 0.56, 0.42][i], [12, 15, 19, 23, 30, 42][i], [1, 1, 2, 2, 3, 5][i], [0, 0, 1, 1, 3, 99][i])
    }
    static func swarm(_ l: Int) -> (bots: Int, damage: Double, cooldown: Double) {
        let i = max(0, min(evolvedLevel - 1, l - 1))
        return ([1, 2, 3, 4, 6, 8][i], [10, 12, 14, 17, 22, 32][i], [1.2, 1.1, 1.0, 0.9, 0.8, 0.6][i])
    }
    static func shield(_ l: Int) -> (orbs: Int, damage: Double, radius: Double) {
        let i = max(0, min(evolvedLevel - 1, l - 1))
        return ([2, 3, 3, 4, 5, 7][i], [8, 10, 13, 16, 20, 30][i], [78, 82, 88, 94, 100, 118][i])
    }
    static func field(_ l: Int) -> (radius: Double, damage: Double) {
        let i = max(0, min(evolvedLevel - 1, l - 1))
        return ([70, 84, 98, 114, 130, 168][i], [5, 6.5, 8, 10.5, 14, 21][i])
    }
    static func zap(_ l: Int) -> (cooldown: Double, jumps: Int, damage: Double) {
        let i = max(0, min(evolvedLevel - 1, l - 1))
        return ([1.6, 1.45, 1.3, 1.15, 1.0, 0.6][i], [3, 4, 5, 6, 7, 11][i], [16, 19, 23, 28, 34, 46][i])
    }
    static func freeze(_ l: Int) -> (cooldown: Double, radius: Double, damage: Double, slow: Double) {
        let i = max(0, min(evolvedLevel - 1, l - 1))
        return ([3.0, 2.7, 2.4, 2.1, 1.8, 1.2][i], [110, 125, 140, 155, 170, 230][i], [6, 8, 10, 13, 16, 26][i], [0.45, 0.5, 0.5, 0.55, 0.6, 0.75][i])
    }
    static func missile(_ l: Int) -> (cooldown: Double, count: Int, damage: Double, blast: Double) {
        let i = max(0, min(evolvedLevel - 1, l - 1))
        return ([1.6, 1.45, 1.3, 1.15, 1.0, 0.7][i], [1, 2, 2, 3, 4, 6][i], [20, 24, 29, 35, 42, 58][i], [50, 55, 60, 65, 70, 95][i])
    }
    static func saw(_ l: Int) -> (blades: Int, damage: Double, radius: Double) {
        let i = max(0, min(evolvedLevel - 1, l - 1))
        return ([2, 2, 3, 3, 4, 6][i], [14, 18, 22, 27, 33, 48][i], [130, 135, 140, 148, 155, 185][i])
    }
    static func rain(_ l: Int) -> (cooldown: Double, strikes: Int, damage: Double, radius: Double) {
        let i = max(0, min(evolvedLevel - 1, l - 1))
        return ([2.0, 1.85, 1.7, 1.55, 1.4, 1.0][i], [3, 4, 5, 6, 7, 10][i], [22, 26, 31, 37, 44, 60][i], [48, 50, 54, 58, 62, 75][i])
    }
    static func bomb(_ l: Int) -> (cooldown: Double, radius: Double, damage: Double) {
        let i = max(0, min(evolvedLevel - 1, l - 1))
        return ([2.2, 2.0, 1.8, 1.6, 1.4, 1.0][i], [80, 88, 98, 108, 120, 155][i], [30, 38, 48, 58, 70, 100][i])
    }
}

/// Persists SaveData in UserDefaults.
final class SaveStore {
    static let shared = SaveStore()
    private let key = "vh2.save"
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> SaveData {
        guard let d = defaults.data(forKey: key), let s = try? JSONDecoder().decode(SaveData.self, from: d) else { return SaveData() }
        return s
    }
    func save(_ s: SaveData) {
        if let d = try? JSONEncoder().encode(s) { defaults.set(d, forKey: key) }
    }
}

/// Coins earned from a finished run.
func runCoins(collected: Int, kills: Int, cleared: Organ?, bonus: Double) -> Int {
    let base = Double(collected) + Double(kills) / 10 + Double(cleared?.coinReward ?? 0)
    return Int((base * bonus).rounded())
}
