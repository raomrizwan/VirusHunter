import Foundation

/// Every city after the first has its own twist, so each outbreak plays differently.
/// The order is shuffled per country, and the map only reveals a city's mutation once the
/// outbreak reaches it.
enum CityMutation: String, CaseIterable {
    case none, splitters, giants, darkness, toxic, twinBoss, speedStrain, ghosts, swarm, armored

    var title: String {
        switch self {
        case .none: return "Original Strain"
        case .splitters: return "Splitter Strain"
        case .giants: return "Giant Strain"
        case .darkness: return "Blackout"
        case .toxic: return "Toxic Ground"
        case .twinBoss: return "Twin Bosses"
        case .speedStrain: return "Speed Strain"
        case .ghosts: return "Ghost Strain"
        case .swarm: return "Swarm Surge"
        case .armored: return "Armored Army"
        }
    }

    var detail: String {
        switch self {
        case .none: return "The virus as we first met it."
        case .splitters: return "Viruses burst into two minis when destroyed."
        case .giants: return "Huge, slow viruses with lots of health. Double DNA."
        case .darkness: return "The lights are out. Nano only sees what's close."
        case .toxic: return "Toxic puddles bubble up around Nano. Keep moving!"
        case .twinBoss: return "Two bosses at once. Beat both to save the organ."
        case .speedStrain: return "Fast, fragile viruses. Don't stop moving."
        case .ghosts: return "Viruses turn invisible until they get close."
        case .swarm: return "Way more viruses, a little weaker each."
        case .armored: return "Elite viruses arrive every few seconds."
        }
    }

    var symbol: String {
        switch self {
        case .none: return "allergens"
        case .splitters: return "circle.grid.2x1.fill"
        case .giants: return "arrow.up.left.and.arrow.down.right"
        case .darkness: return "moon.fill"
        case .toxic: return "drop.fill"
        case .twinBoss: return "person.2.fill"
        case .speedStrain: return "hare.fill"
        case .ghosts: return "eye.slash.fill"
        case .swarm: return "aqi.high"
        case .armored: return "shield.fill"
        }
    }

    /// Mutation for a city (Infection Level) in a country: city 1 is always the original strain,
    /// cities 2-10 get the nine twists in a country-specific order.
    static func forCity(_ level: Int, country: String) -> CityMutation {
        guard level >= 2 else { return .none }
        var rng = SeededRNG(seed: country.utf8.reduce(UInt64(1469598103)) { ($0 &* 31) &+ UInt64($1) })
        let order = Array(allCases.dropFirst()).shuffled(using: &rng)
        return order[(level - 2) % order.count]
    }

    // Numbers the game scene applies.
    var healthScale: Double {
        switch self {
        case .giants: return 1.8
        case .speedStrain: return 0.75
        case .swarm: return 0.7
        case .armored: return 1.15
        default: return 1
        }
    }
    var speedScale: Double {
        switch self {
        case .giants: return 0.8
        case .speedStrain: return 1.35
        default: return 1
        }
    }
    var sizeScale: Double { self == .giants ? 1.35 : 1 }
    var xpScale: Int { self == .giants ? 2 : 1 }
    var spawnScale: Double { self == .swarm ? 1.6 : self == .giants ? 0.75 : 1 }
    /// Seconds between elites (nil = organ default).
    var eliteInterval: Double? { self == .armored ? 18 : nil }
}

extension Organ {
    /// The mutation this run plays with (Endless has none).
    func mutation(country: String) -> CityMutation {
        isSideMode ? .none : CityMutation.forCity(infection, country: country)
    }
}
