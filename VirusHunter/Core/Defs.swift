import Foundation

// MARK: - Weapons & passives

enum WeaponKind: String, CaseIterable, Codable, Identifiable {
    case laser, swarm, shield, field, zap, bomb
    var id: String { rawValue }
    var title: String {
        switch self {
        case .laser: return "Pulse Laser"
        case .swarm: return "Nano Swarm"
        case .shield: return "Antibody Shield"
        case .field: return "Shock Field"
        case .zap: return "Chain Zap"
        case .bomb: return "Cure Bomb"
        }
    }
    var symbol: String {
        switch self {
        case .laser: return "bolt.horizontal.fill"
        case .swarm: return "circle.hexagongrid.fill"
        case .shield: return "shield.lefthalf.filled"
        case .field: return "dot.radiowaves.left.and.right"
        case .zap: return "bolt.fill"
        case .bomb: return "cross.circle.fill"
        }
    }
    /// One-line description of what the next level gives.
    func detail(nextLevel l: Int) -> String {
        switch self {
        case .laser: return l == 1 ? "Fires at the nearest virus." : l == 5 ? "Bolts pierce through viruses." : "+damage, more bolts."
        case .swarm: return l == 1 ? "A mini-bot hunts viruses for you." : "+1 mini-bot, +damage."
        case .shield: return l == 1 ? "Antibodies orbit and knock viruses back." : "+1 antibody, +damage."
        case .field: return l == 1 ? "An electric aura zaps anything close." : "Bigger aura, +damage."
        case .zap: return l == 1 ? "Lightning jumps between viruses." : "+2 jumps, +damage."
        case .bomb: return l == 1 ? "Drops cure bombs as you fly." : "Bigger blast, faster drops."
        }
    }
}

enum PassiveKind: String, CaseIterable, Codable, Identifiable {
    case speed, maxHP, magnet, power, rapid, regen
    var id: String { rawValue }
    var title: String {
        switch self {
        case .speed: return "Turbo Jets"
        case .maxHP: return "Nano Armor"
        case .magnet: return "DNA Magnet"
        case .power: return "Overcharge"
        case .rapid: return "Rapid Cooling"
        case .regen: return "Self-Repair"
        }
    }
    var symbol: String {
        switch self {
        case .speed: return "hare.fill"
        case .maxHP: return "heart.fill"
        case .magnet: return "dot.circle.and.hand.point.up.left.fill"
        case .power: return "flame.fill"
        case .rapid: return "timer"
        case .regen: return "cross.case.fill"
        }
    }
    var detail: String {
        switch self {
        case .speed: return "+8% move speed."
        case .maxHP: return "+20 max health."
        case .magnet: return "+30% pickup range."
        case .power: return "+10% damage for all weapons."
        case .rapid: return "Weapons cool down 8% faster."
        case .regen: return "Recover 0.6 health per second."
        }
    }
}

enum UpgradeOption: Hashable, Identifiable {
    case weapon(WeaponKind, toLevel: Int)
    case passive(PassiveKind, toLevel: Int)
    case heal
    case coins(Int)

    var id: String {
        switch self {
        case .weapon(let w, let l): return "w-\(w.rawValue)-\(l)"
        case .passive(let p, let l): return "p-\(p.rawValue)-\(l)"
        case .heal: return "heal"
        case .coins(let n): return "coins-\(n)"
        }
    }
}

let maxWeapons = 4
let maxLevel = 5

/// What the player owns during one run.
struct Loadout: Equatable {
    var weapons: [WeaponKind: Int] = [.laser: 1]
    var weaponOrder: [WeaponKind] = [.laser]
    var passives: [PassiveKind: Int] = [:]

    func level(_ w: WeaponKind) -> Int { weapons[w] ?? 0 }
    func level(_ p: PassiveKind) -> Int { passives[p] ?? 0 }

    mutating func apply(_ o: UpgradeOption) {
        switch o {
        case .weapon(let w, let l):
            if weapons[w] == nil { weaponOrder.append(w) }
            weapons[w] = l
        case .passive(let p, let l): passives[p] = l
        case .heal, .coins: break
        }
    }

    /// All upgrades currently possible.
    func candidates() -> [UpgradeOption] {
        var out: [UpgradeOption] = []
        for w in WeaponKind.allCases {
            let l = level(w)
            if l > 0, l < maxLevel { out.append(.weapon(w, toLevel: l + 1)) }
            if l == 0, weapons.count < maxWeapons { out.append(.weapon(w, toLevel: 1)) }
        }
        for p in PassiveKind.allCases where level(p) < maxLevel { out.append(.passive(p, toLevel: level(p) + 1)) }
        return out
    }

    /// Picks `count` distinct options. Owned weapons' level-ups are weighted up so builds come together.
    func rollOptions<R: RandomNumberGenerator>(count: Int = 3, rng: inout R) -> [UpgradeOption] {
        var pool = candidates().map { o -> (UpgradeOption, Double) in
            switch o {
            case .weapon(_, let l): return (o, l == 1 ? 1.1 : 1.6)
            case .passive: return (o, 0.8)
            default: return (o, 1)
            }
        }
        var picks: [UpgradeOption] = []
        while picks.count < count, !pool.isEmpty {
            let total = pool.reduce(0) { $0 + $1.1 }
            var x = Double.random(in: 0..<total, using: &rng)
            var idx = 0
            for (i, p) in pool.enumerated() { x -= p.1; if x < 0 { idx = i; break } }
            picks.append(pool[idx].0)
            pool.remove(at: idx)
        }
        let fallbacks: [UpgradeOption] = [.heal, .coins(25), .coins(50)]
        for f in fallbacks where picks.count < count { picks.append(f) }
        return picks
    }
}

/// XP needed to go from `level` to `level + 1`.
func xpToNext(_ level: Int) -> Int { 4 + 3 * level + Int(pow(Double(level), 1.5)) }

// MARK: - Enemies

enum EnemyKind: String, CaseIterable {
    case spiky, mini, blob, dart, spitter, elite
    case bossSumo, bossCowboy, bossRoyal

    struct Stats { let hp: Double; let speed: Double; let radius: Double; let damage: Double; let xp: Int }

    var base: Stats {
        switch self {
        case .spiky: return Stats(hp: 14, speed: 62, radius: 16, damage: 10, xp: 1)
        case .mini: return Stats(hp: 6, speed: 105, radius: 10, damage: 6, xp: 1)
        case .blob: return Stats(hp: 42, speed: 40, radius: 25, damage: 14, xp: 3)
        case .dart: return Stats(hp: 18, speed: 55, radius: 15, damage: 12, xp: 2)
        case .spitter: return Stats(hp: 22, speed: 52, radius: 16, damage: 8, xp: 2)
        case .elite: return Stats(hp: 240, speed: 58, radius: 30, damage: 18, xp: 15)
        case .bossSumo: return Stats(hp: 2000, speed: 46, radius: 62, damage: 26, xp: 60)
        case .bossCowboy: return Stats(hp: 1800, speed: 58, radius: 56, damage: 22, xp: 60)
        case .bossRoyal: return Stats(hp: 2300, speed: 42, radius: 60, damage: 24, xp: 60)
        }
    }
    var isBoss: Bool { self == .bossSumo || self == .bossCowboy || self == .bossRoyal }
    var texture: String {
        switch self {
        case .bossSumo: return "boss-sumo"
        case .bossCowboy: return "boss-cowboy"
        case .bossRoyal: return "boss-royal"
        default: return "virus-\(rawValue)"
        }
    }
    /// Sprite size relative to the hit radius (art includes spikes and glow).
    var spriteScale: Double { isBoss ? 2.6 : self == .blob ? 2.3 : 2.9 }
    var bossTitle: String {
        switch self {
        case .bossSumo: return "Sumo Virus"
        case .bossCowboy: return "Cowboy Virus"
        case .bossRoyal: return "Royal Guard"
        default: return ""
        }
    }
}

// MARK: - Stages (organs)

struct Organ: Identifiable, Equatable {
    let id: Int          // 1-based stage number; 0 = endless
    let name: String
    let key: String      // background texture key
    let boss: EnemyKind
    let tagline: String

    static let all: [Organ] = [
        Organ(id: 1, name: "Lungs", key: "lungs", boss: .bossSumo, tagline: "Clear the airways."),
        Organ(id: 2, name: "Heart", key: "heart", boss: .bossCowboy, tagline: "Keep the blood flowing."),
        Organ(id: 3, name: "Stomach", key: "stomach", boss: .bossRoyal, tagline: "Acid and armies."),
        Organ(id: 4, name: "Brain", key: "brain", boss: .bossSumo, tagline: "Save the mind."),
        Organ(id: 5, name: "Bone Marrow", key: "marrow", boss: .bossCowboy, tagline: "The source of the swarm."),
    ]
    static let endless = Organ(id: 0, name: "Endless", key: "endless", boss: .bossRoyal, tagline: "How long can you last?")

    var isEndless: Bool { id == 0 }
    /// Stage difficulty multiplier for enemy health and damage.
    var difficulty: Double { isEndless ? 1.4 : 1 + 0.55 * Double(id - 1) }
    /// Seconds until the boss appears.
    var bossTime: Double { isEndless ? 180 : 240 }
    var coinReward: Int { isEndless ? 0 : 60 + 30 * id }
}

/// Spawn schedule: which kinds appear and how fast, as a function of elapsed time.
enum Spawner {
    /// Enemies per second.
    static func rate(time t: Double, organ: Organ) -> Double {
        let stage = organ.isEndless ? 3 : organ.id
        let base = 1.5 + 0.2 * Double(stage - 1)
        let warmup = min(1, 0.55 + t / 45) // gentler first ~20 s
        return min(18, base * (1 + t / 32) * warmup)
    }

    static func kinds(time t: Double) -> [(EnemyKind, Double)] {
        var k: [(EnemyKind, Double)] = [(.spiky, 6), (.mini, 2)]
        if t > 50 { k.append((.dart, 2.5)) }
        if t > 100 { k.append((.blob, 2)) }
        if t > 130 { k.append((.spitter, 1.6)) }
        return k
    }

    /// Health multiplier from elapsed time.
    static func healthScale(time t: Double) -> Double { 1 + 0.22 * (t / 60) + 0.05 * pow(t / 60, 2) }

    static func pick<R: RandomNumberGenerator>(time t: Double, rng: inout R) -> EnemyKind {
        let k = kinds(time: t)
        let total = k.reduce(0) { $0 + $1.1 }
        var x = Double.random(in: 0..<total, using: &rng)
        for (kind, w) in k { x -= w; if x < 0 { return kind } }
        return .spiky
    }
}
