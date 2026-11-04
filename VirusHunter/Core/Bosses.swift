import Foundation

// MARK: - Boss lineups and special viruses per city
//
// City 1 plays the classic lineup (each organ's own boss). From the second city on, every city
// shuffles which boss guards which organ and gives each one a different variant, so the five
// bosses of a city are always five different fights. The order is seeded by country and city,
// so two countries play differently but a city always stays the same after a retry.
// Each organ also has its own signature virus, and later cities bring a guest virus on top.

enum BossVariant: String, CaseIterable {
    case normal, frost, toxic, inferno, shadow, mega

    /// Word in front of the boss name ("Toxic Sumo Virus").
    var prefix: String {
        switch self {
        case .normal: return ""
        case .frost: return "Frost"
        case .toxic: return "Toxic"
        case .inferno: return "Inferno"
        case .shadow: return "Shadow"
        case .mega: return "Mega"
        }
    }

    var detail: String {
        switch self {
        case .normal: return "The classic fight."
        case .frost: return "Its shots chill Nano and slow it down."
        case .toxic: return "Leaves toxic puddles wherever it goes."
        case .inferno: return "Bursts out rings of fire."
        case .shadow: return "Turns invisible and speeds up."
        case .mega: return "Huge, tough, and calls for backup when hurt."
        }
    }

    var hpScale: Double { self == .mega ? 1.5 : self == .shadow ? 0.9 : 1 }
    var sizeScale: Double { self == .mega ? 1.25 : 1 }
    var speedScale: Double { self == .shadow ? 1.25 : self == .mega ? 0.9 : 1 }
    /// Signature color (shots, effects) as RGB plus a body blend amount (nil = original colors).
    var tint: (r: Double, g: Double, b: Double, amount: Double)? {
        switch self {
        case .normal: return nil
        case .frost: return (0.55, 0.85, 1, 0.45)
        case .toxic: return (0.45, 1, 0.25, 0.45)
        case .inferno: return (1, 0.45, 0.15, 0.45)
        case .shadow: return (0.35, 0.15, 0.55, 0.55)
        case .mega: return (1, 0.3, 0.3, 0.25)
        }
    }
    /// Variants a boss can roll after the first city.
    static let twists: [BossVariant] = [.frost, .toxic, .inferno, .shadow, .mega]
}

struct BossSetup: Equatable {
    let kind: EnemyKind
    let variant: BossVariant
    var title: String { variant == .normal ? kind.bossTitle : "\(variant.prefix) \(kind.bossTitle)" }
    /// Each variant boss has its own art ("boss-sumo-frost").
    var texture: String { variant == .normal ? kind.texture : "\(kind.texture)-\(variant.rawValue)" }
}

private func citySeed(_ country: String, _ level: Int, salt: UInt64) -> SeededRNG {
    SeededRNG(seed: country.utf8.reduce(salt &+ UInt64(level) &* 0x9E37) { ($0 &* 131) &+ UInt64($1) })
}

extension Organ {
    /// The boss this organ's run ends with, and its variant, for a country.
    func bossSetup(country: String) -> BossSetup {
        if isSideMode { return BossSetup(kind: boss, variant: .normal) }
        if finalBoss == .bossVex { return BossSetup(kind: .bossVex, variant: .normal) }
        guard infection >= 2 else { return BossSetup(kind: boss, variant: .normal) }
        var rng = citySeed(country, infection, salt: 7_919)
        let kinds = EnemyKind.bossRoster.shuffled(using: &rng)
        let variants = BossVariant.twists.shuffled(using: &rng)
        let i = max(0, min(kinds.count - 1, id - 1))
        return BossSetup(kind: kinds[i], variant: variants[i])
    }

    /// The organ's own signature virus (Bone Marrow, the source, has no single one).
    var signature: EnemyKind? {
        switch id {
        case 1: return .spore
        case 2: return .bomber
        case 3: return .healer
        case 4: return .sniper
        default: return nil
        }
    }

    /// Special viruses joining this run's mix, signature first: Bone Marrow and later cities
    /// add guests picked per country and city.
    func extraKinds(country: String) -> [EnemyKind] {
        if isSideMode { return EnemyKind.specials }
        var out: [EnemyKind] = signature.map { [$0] } ?? []
        var rng = citySeed(country, infection, salt: 104_729 &+ UInt64(id))
        let guests = EnemyKind.specials.filter { !out.contains($0) }.shuffled(using: &rng)
        let count = (signature == nil ? 2 : 0) + (infection >= 2 ? 1 : 0) + (infection >= 6 ? 1 : 0)
        out += guests.prefix(count)
        return out
    }
}

// MARK: - City strains, mini bosses, backgrounds

/// From the second city on, the regular viruses of each city wear a new look (horns, crystals,
/// helmets...), so every outbreak has its own army. Shuffled per country like the mutations.
enum VirusStrain: String, CaseIterable {
    case horned, crystal, armored, punk, cyclops, zombie, gold, ninja, pirate

    var title: String { "\(rawValue.prefix(1).uppercased())\(rawValue.dropFirst()) Strain" }
    /// Kinds that change their look (the special viruses keep theirs).
    static let kinds: [EnemyKind] = [.spiky, .mini, .blob, .dart, .spitter, .elite]
    /// Color the arena takes on in this city.
    var tint: (r: Double, g: Double, b: Double) {
        switch self {
        case .horned: return (1, 0.25, 0.25)
        case .crystal: return (0.35, 0.9, 1)
        case .armored: return (0.6, 0.66, 0.78)
        case .punk: return (0.95, 0.25, 0.8)
        case .cyclops: return (1, 0.62, 0.15)
        case .zombie: return (0.55, 0.68, 0.45)
        case .gold: return (0.95, 0.76, 0.2)
        case .ninja: return (0.3, 0.3, 0.42)
        case .pirate: return (0.15, 0.8, 0.62)
        }
    }

    /// City 1 has the original viruses; cities 2-10 each get a different strain.
    static func forCity(_ level: Int, country: String) -> VirusStrain? {
        guard level >= 2 else { return nil }
        var rng = citySeed(country, 0, salt: 31_337)
        let order = allCases.shuffled(using: &rng)
        return order[(level - 2) % order.count]
    }
}

extension EnemyKind {
    /// Texture in a city strain ("virus-spiky-horned"); special viruses and bosses keep their own.
    func texture(strain: VirusStrain?) -> String {
        guard let strain, VirusStrain.kinds.contains(self) else { return texture }
        return "\(texture)-\(strain.rawValue)"
    }
}

extension Organ {
    func strain(country: String) -> VirusStrain? { isSideMode ? nil : VirusStrain.forCity(infection, country: country) }

    /// The mini boss that shows up mid-run (a different one per organ and city).
    func miniBoss(country: String) -> EnemyKind {
        var rng = citySeed(country, infection, salt: 4_243 &+ UInt64(id))
        return EnemyKind.miniBosses.randomElement(using: &rng) ?? .miniQueen
    }

    /// Arena background: even cities use the organ's second, more infected look.
    var backdrop: String { !isSideMode && infection % 2 == 0 ? "bg-\(key)-2" : "bg-\(key)" }
}
