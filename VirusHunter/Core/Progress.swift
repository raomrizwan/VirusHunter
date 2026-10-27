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
    func effect(_ level: Int) -> String {
        switch self {
        case .power: return "+\(level * 5)% damage"
        case .armor: return "−\(level * 3)% damage taken"
        case .health: return "+\(level * 10) max health"
        case .speed: return "+\(level * 3)% speed"
        case .magnet: return "+\(level * 8)% pickup range"
        case .greed: return "+\(level * 8)% Bio-Coins"
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

    func level(_ t: TechKind) -> Int { tech[t.rawValue] ?? 0 }

    mutating func buy(_ t: TechKind) -> Bool {
        let l = level(t)
        guard l < t.maxLevel else { return false }
        let c = t.cost(toLevel: l + 1)
        guard coins >= c else { return false }
        coins -= c
        tech[t.rawValue] = l + 1
        return true
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
            maxHP: 100 + Double(save.level(.health) * 10) + Double((p[.maxHP] ?? 0) * 20),
            speed: PlayerStats.baseSpeed * (1 + 0.03 * Double(save.level(.speed)) + 0.08 * Double(p[.speed] ?? 0)),
            magnet: 120 * (1 + 0.08 * Double(save.level(.magnet)) + 0.30 * Double(p[.magnet] ?? 0)),
            damage: 1 + 0.05 * Double(save.level(.power)) + 0.10 * Double(p[.power] ?? 0),
            cooldown: max(0.5, 1 - 0.08 * Double(p[.rapid] ?? 0)),
            armor: min(0.5, 0.03 * Double(save.level(.armor))),
            regen: 0.6 * Double(p[.regen] ?? 0),
            coinBonus: 1 + 0.08 * Double(save.level(.greed))
        )
    }
}

/// Weapon numbers per level (index 0 = level 1).
enum WeaponStats {
    static func laser(_ l: Int) -> (cooldown: Double, damage: Double, bolts: Int, pierce: Int) {
        let i = max(0, min(4, l - 1))
        return ([0.85, 0.78, 0.7, 0.64, 0.56][i], [12, 15, 19, 23, 30][i], [1, 1, 2, 2, 3][i], [0, 0, 1, 1, 3][i])
    }
    static func swarm(_ l: Int) -> (bots: Int, damage: Double, cooldown: Double) {
        let i = max(0, min(4, l - 1))
        return ([1, 2, 3, 4, 6][i], [10, 12, 14, 17, 22][i], [1.2, 1.1, 1.0, 0.9, 0.8][i])
    }
    static func shield(_ l: Int) -> (orbs: Int, damage: Double, radius: Double) {
        let i = max(0, min(4, l - 1))
        return ([2, 3, 3, 4, 5][i], [8, 10, 13, 16, 20][i], [78, 82, 88, 94, 100][i])
    }
    static func field(_ l: Int) -> (radius: Double, damage: Double) {
        let i = max(0, min(4, l - 1))
        return ([70, 84, 98, 114, 130][i], [5, 6.5, 8, 10.5, 14][i])
    }
    static func zap(_ l: Int) -> (cooldown: Double, jumps: Int, damage: Double) {
        let i = max(0, min(4, l - 1))
        return ([1.6, 1.45, 1.3, 1.15, 1.0][i], [3, 4, 5, 6, 7][i], [16, 19, 23, 28, 34][i])
    }
    static func bomb(_ l: Int) -> (cooldown: Double, radius: Double, damage: Double) {
        let i = max(0, min(4, l - 1))
        return ([2.2, 2.0, 1.8, 1.6, 1.4][i], [80, 88, 98, 108, 120][i], [30, 38, 48, 58, 70][i])
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
