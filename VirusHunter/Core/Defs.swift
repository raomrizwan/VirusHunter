import Foundation

// MARK: - Weapons & passives

enum WeaponKind: String, CaseIterable, Codable, Identifiable {
    case laser, swarm, shield, field, zap, bomb, freeze, missile
    var id: String { rawValue }
    /// Weapons earned by saving cities (locked until then).
    static let cityRewards: Set<WeaponKind> = [.freeze, .missile]
    var title: String {
        switch self {
        case .laser: return "Pulse Laser"
        case .swarm: return "Nano Swarm"
        case .shield: return "Antibody Shield"
        case .field: return "Shock Field"
        case .zap: return "Chain Zap"
        case .bomb: return "Cure Bomb"
        case .freeze: return "Freeze Ray"
        case .missile: return "Homing Missiles"
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
        case .freeze: return "snowflake"
        case .missile: return "location.north.fill"
        }
    }
    /// Evolved form, reached at level `evolvedLevel` once the weapon is maxed and its partner passive is owned.
    var evolvedTitle: String {
        switch self {
        case .laser: return "Photon Lance"
        case .swarm: return "Hive Mind"
        case .shield: return "Immune Wall"
        case .field: return "Storm Field"
        case .zap: return "Thunderstorm"
        case .bomb: return "Cure Nova"
        case .freeze: return "Absolute Zero"
        case .missile: return "Rocket Storm"
        }
    }
    /// The passive that unlocks this weapon's evolution.
    var partner: PassiveKind {
        switch self {
        case .laser: return .rapid
        case .swarm: return .power
        case .shield: return .maxHP
        case .field: return .magnet
        case .zap: return .speed
        case .bomb: return .regen
        case .freeze: return .magnet
        case .missile: return .power
        }
    }
    func displayTitle(level l: Int) -> String { l >= evolvedLevel ? evolvedTitle : title }

    /// One-line description of what the next level gives.
    func detail(nextLevel l: Int) -> String {
        if l >= evolvedLevel {
            switch self {
            case .laser: return "EVOLVE: 5 piercing photon bolts that pass through everything."
            case .swarm: return "EVOLVE: 8 hunter bots with heavy damage."
            case .shield: return "EVOLVE: 7 antibodies in a wide, crushing orbit."
            case .field: return "EVOLVE: a huge storm aura that shreds viruses."
            case .zap: return "EVOLVE: lightning jumps 11 times, twice as often."
            case .bomb: return "EVOLVE: giant cure blasts every second."
            case .freeze: return "EVOLVE: a huge frost wave that nearly stops viruses."
            case .missile: return "EVOLVE: six heavy rockets with big blasts."
            }
        }
        switch self {
        case .laser: return l == 1 ? "Fires at the nearest virus." : l == 5 ? "Bolts pierce through viruses." : "+damage, more bolts."
        case .swarm: return l == 1 ? "A mini-bot hunts viruses for you." : "+1 mini-bot, +damage."
        case .shield: return l == 1 ? "Antibodies orbit and knock viruses back." : "+1 antibody, +damage."
        case .field: return l == 1 ? "An electric aura zaps anything close." : "Bigger aura, +damage."
        case .zap: return l == 1 ? "Lightning jumps between viruses." : "+2 jumps, +damage."
        case .bomb: return l == 1 ? "Drops cure bombs as you fly." : "Bigger blast, faster drops."
        case .freeze: return l == 1 ? "A frost wave slows and chills nearby viruses." : "Bigger, colder, more often."
        case .missile: return l == 1 ? "Fires a missile that chases viruses and explodes." : "+missiles, +damage."
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
/// Weapon "level 6": the evolved form.
let evolvedLevel = 6

/// What the player owns during one run.
struct Loadout: Equatable {
    var weapons: [WeaponKind: Int] = [.laser: 1]
    var weaponOrder: [WeaponKind] = [.laser]
    var passives: [PassiveKind: Int] = [:]
    /// Weapons not available yet (city rewards not earned).
    var locked: Set<WeaponKind> = WeaponKind.cityRewards

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
            if l == maxLevel, level(w.partner) > 0 { out.append(.weapon(w, toLevel: evolvedLevel)) }
            if l == 0, weapons.count < maxWeapons, !locked.contains(w) { out.append(.weapon(w, toLevel: 1)) }
        }
        for p in PassiveKind.allCases where level(p) < maxLevel { out.append(.passive(p, toLevel: level(p) + 1)) }
        return out
    }

    /// Picks `count` distinct options. Owned weapons' level-ups are weighted up so builds come together.
    func rollOptions<R: RandomNumberGenerator>(count: Int = 3, rng: inout R) -> [UpgradeOption] {
        var pool = candidates().map { o -> (UpgradeOption, Double) in
            switch o {
            case .weapon(_, let l): return (o, l == 1 ? 1.1 : l >= evolvedLevel ? 4 : 1.6)
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
    case bomber, healer, sniper, spore
    case miniQueen, miniTurret, miniRhino, miniMagnet
    case bossSumo, bossCowboy, bossRoyal, bossBrain, bossMarrow, bossVex

    struct Stats { let hp: Double; let speed: Double; let radius: Double; let damage: Double; let xp: Int }

    var base: Stats {
        switch self {
        case .spiky: return Stats(hp: 14, speed: 62, radius: 16, damage: 10, xp: 1)
        case .mini: return Stats(hp: 6, speed: 105, radius: 10, damage: 6, xp: 1)
        case .blob: return Stats(hp: 42, speed: 40, radius: 25, damage: 14, xp: 3)
        case .dart: return Stats(hp: 18, speed: 55, radius: 15, damage: 12, xp: 2)
        case .spitter: return Stats(hp: 22, speed: 52, radius: 16, damage: 8, xp: 2)
        case .elite: return Stats(hp: 240, speed: 58, radius: 30, damage: 18, xp: 15)
        case .bomber: return Stats(hp: 20, speed: 80, radius: 16, damage: 10, xp: 2)
        case .healer: return Stats(hp: 30, speed: 48, radius: 17, damage: 8, xp: 3)
        case .sniper: return Stats(hp: 20, speed: 50, radius: 15, damage: 8, xp: 3)
        case .spore: return Stats(hp: 8, speed: 72, radius: 11, damage: 6, xp: 1)
        case .miniQueen: return Stats(hp: 650, speed: 40, radius: 34, damage: 18, xp: 25)
        case .miniTurret: return Stats(hp: 700, speed: 22, radius: 32, damage: 16, xp: 25)
        case .miniRhino: return Stats(hp: 600, speed: 50, radius: 32, damage: 22, xp: 25)
        case .miniMagnet: return Stats(hp: 600, speed: 45, radius: 32, damage: 18, xp: 25)
        case .bossSumo: return Stats(hp: 2000, speed: 46, radius: 62, damage: 26, xp: 60)
        case .bossCowboy: return Stats(hp: 1800, speed: 58, radius: 56, damage: 22, xp: 60)
        case .bossRoyal: return Stats(hp: 2300, speed: 42, radius: 60, damage: 24, xp: 60)
        case .bossBrain: return Stats(hp: 2100, speed: 50, radius: 58, damage: 24, xp: 60)
        case .bossMarrow: return Stats(hp: 2600, speed: 34, radius: 66, damage: 30, xp: 60)
        case .bossVex: return Stats(hp: 3400, speed: 52, radius: 64, damage: 30, xp: 80)
        }
    }
    var isBoss: Bool { [.bossSumo, .bossCowboy, .bossRoyal, .bossBrain, .bossMarrow, .bossVex].contains(self) }
    var texture: String {
        switch self {
        case .bossSumo: return "boss-sumo"
        case .bossCowboy: return "boss-cowboy"
        case .bossRoyal: return "boss-royal"
        case .bossBrain: return "boss-brain"
        case .bossMarrow: return "boss-marrow"
        case .bossVex: return "king-vex"
        case .miniQueen: return "miniboss-queen"
        case .miniTurret: return "miniboss-turret"
        case .miniRhino: return "miniboss-rhino"
        case .miniMagnet: return "miniboss-magnet"
        default: return "virus-\(rawValue)"
        }
    }
    /// Sprite size relative to the hit radius (art includes spikes and glow).
    var spriteScale: Double { isBoss || isMiniBoss ? 2.6 : self == .blob ? 2.3 : 2.9 }
    var isMiniBoss: Bool { EnemyKind.miniBosses.contains(self) }
    static let miniBosses: [EnemyKind] = [.miniQueen, .miniTurret, .miniRhino, .miniMagnet]
    /// Mini boss name shown when it arrives.
    var miniTitle: String {
        switch self {
        case .miniQueen: return "Brood Queen"
        case .miniTurret: return "Turret Tick"
        case .miniRhino: return "Rhino Charger"
        case .miniMagnet: return "Magnet Mite"
        default: return ""
        }
    }
    var bossTitle: String {
        switch self {
        case .bossSumo: return "Sumo Virus"
        case .bossCowboy: return "Cowboy Virus"
        case .bossRoyal: return "Royal Guard"
        case .bossBrain: return "Mind Leech"
        case .bossMarrow: return "Bone Colossus"
        case .bossVex: return "King Vex"
        default: return ""
        }
    }
    /// The four special viruses that change how a stage plays (see `Organ.extraKinds`).
    static let specials: [EnemyKind] = [.bomber, .healer, .sniper, .spore]
    /// Bosses that can lead an outbreak (King Vex only appears at the very end).
    static let bossRoster: [EnemyKind] = [.bossSumo, .bossCowboy, .bossRoyal, .bossBrain, .bossMarrow]
}

// MARK: - Stages (organs)

struct Organ: Identifiable, Equatable {
    let id: Int          // 1-based stage number; 0 = endless
    let name: String
    let key: String      // background texture key
    let boss: EnemyKind
    let tagline: String
    /// Infection Level (1...maxInfection). Cleared organs can be replayed at higher levels for bigger rewards.
    var infection: Int = 1

    static let maxInfection = 10
    static let all: [Organ] = [
        Organ(id: 1, name: "Lungs", key: "lungs", boss: .bossSumo, tagline: "Clear the airways."),
        Organ(id: 2, name: "Heart", key: "heart", boss: .bossCowboy, tagline: "Keep the blood flowing."),
        Organ(id: 3, name: "Stomach", key: "stomach", boss: .bossRoyal, tagline: "Acid and armies."),
        Organ(id: 4, name: "Brain", key: "brain", boss: .bossBrain, tagline: "Save the mind."),
        Organ(id: 5, name: "Bone Marrow", key: "marrow", boss: .bossMarrow, tagline: "The source of the swarm."),
    ]
    static let endless = Organ(id: 0, name: "Endless", key: "endless", boss: .bossRoyal, tagline: "How long can you last?")
    /// Weekly Boss Rush: five bosses back to back.
    static let bossRush = Organ(id: 6, name: "Boss Rush", key: "endless", boss: .bossSumo, tagline: "Five bosses, back to back.")

    var isEndless: Bool { id == 0 }
    var isBossRush: Bool { id == 6 }
    /// Endless and Boss Rush are side modes: they never count toward the outbreak.
    var isSideMode: Bool { isEndless || isBossRush }
    /// The boss actually fought: King Vex waits in the Bone Marrow of the final city.
    var finalBoss: EnemyKind { id == 5 && infection >= Organ.maxInfection ? .bossVex : boss }
    /// This organ at another Infection Level (clamped to 1...maxInfection).
    func at(infection level: Int) -> Organ { var o = self; o.infection = max(1, min(Organ.maxInfection, level)); return o }
    /// Extra steps above Infection Level 1.
    private var heat: Double { isSideMode ? 0 : Double(infection - 1) }
    /// Stage difficulty multiplier for enemy health and damage.
    var difficulty: Double { (isEndless ? 1.4 : isBossRush ? 2.2 : 1 + 0.55 * Double(id - 1)) * (1 + 0.4 * heat) }
    /// Enemy speed multiplier from Infection Level.
    var speedScale: Double { 1 + 0.03 * heat }
    /// Spawn rate multiplier from Infection Level.
    var spawnScale: Double { 1 + 0.07 * heat }
    /// Seconds between elite viruses (they come faster at higher Infection Levels).
    var eliteInterval: Double { max(30, 60 - 3 * heat) }
    /// Seconds until the boss appears.
    var bossTime: Double { isEndless ? 180 : 240 }
    var coinReward: Int { isSideMode ? 0 : Int(Double(60 + 30 * id) * (1 + 0.6 * heat)) }
    /// Multiplier on coins picked up and earned from kills.
    var coinScale: Double { 1 + 0.15 * heat }
}

/// Spawn schedule: which kinds appear and how fast, as a function of elapsed time.
enum Spawner {
    /// Enemies per second.
    static func rate(time t: Double, organ: Organ) -> Double {
        let stage = organ.isEndless ? 3 : organ.isBossRush ? 1 : organ.id
        let base = 1.5 + 0.2 * Double(stage - 1)
        let warmup = min(1, 0.55 + t / 45) // gentler first ~20 s
        return min(18 * organ.spawnScale, base * (1 + t / 32) * warmup * organ.spawnScale)
    }

    /// `extra`: the stage's special viruses (signature first), joining the mix over time.
    static func kinds(time t: Double, extra: [EnemyKind] = []) -> [(EnemyKind, Double)] {
        var k: [(EnemyKind, Double)] = [(.spiky, 6), (.mini, 2)]
        if t > 50 { k.append((.dart, 2.5)) }
        if t > 100 { k.append((.blob, 2)) }
        if t > 130 { k.append((.spitter, 1.6)) }
        for (i, kind) in extra.enumerated() where t > 30 + 45 * Double(i) { k.append((kind, i == 0 ? 1.8 : 1.3)) }
        return k
    }

    /// Health multiplier from elapsed time.
    static func healthScale(time t: Double) -> Double { 1 + 0.22 * (t / 60) + 0.05 * pow(t / 60, 2) }

    static func pick<R: RandomNumberGenerator>(time t: Double, extra: [EnemyKind] = [], rng: inout R) -> EnemyKind {
        let k = kinds(time: t, extra: extra)
        let total = k.reduce(0) { $0 + $1.1 }
        var x = Double.random(in: 0..<total, using: &rng)
        for (kind, w) in k { x -= w; if x < 0 { return kind } }
        return .spiky
    }
}
