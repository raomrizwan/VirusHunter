import Foundation

// MARK: - Pets, Nemesis, Ghost runs

/// Nano's pets: one flies along in every run and levels up (1...10) from season-style run XP.
enum Pet: String, CaseIterable, Identifiable {
    case pip, bloop, zip

    var id: String { rawValue }
    var title: String {
        switch self {
        case .pip: return "Pip the Probiotic"
        case .bloop: return "Bloop the Platelet"
        case .zip: return "Zip the Spark Bug"
        }
    }
    var detail: String {
        switch self {
        case .pip: return "Fetches DNA and coins from far away."
        case .bloop: return "Blows a bubble that blocks the next hit."
        case .zip: return "Shoots sparks at the nearest virus."
        }
    }
    var texture: String { "pet-\(rawValue)" }
    var price: Int {
        switch self {
        case .pip: return 0
        case .bloop: return 3_000
        case .zip: return 5_000
        }
    }

    static let maxLevel = 10
    /// Total XP needed to reach each level (index 0 = level 1).
    static let thresholds = [0, 150, 400, 750, 1_200, 1_750, 2_400, 3_150, 4_000, 5_000]

    static func level(xp: Int) -> Int { thresholds.lastIndex { xp >= $0 }.map { $0 + 1 } ?? 1 }

    /// Seconds between actions at a level.
    func cooldown(_ l: Int) -> Double {
        switch self {
        case .pip: return max(3, 7.5 - 0.4 * Double(l))
        case .bloop: return max(10, 24 - 1.4 * Double(l))
        case .zip: return max(0.6, 1.6 - 0.09 * Double(l))
        }
    }
    /// Pip's fetch range and Zip's spark damage at a level.
    static func fetchRange(_ l: Int) -> Double { 240 + 30 * Double(l) }
    static func sparkDamage(_ l: Int) -> Double { 8 + 3.5 * Double(l) }

    func effect(_ l: Int) -> String {
        switch self {
        case .pip: return "Fetches every \(Int(cooldown(l).rounded()))s from \(Int(Pet.fetchRange(l))) away"
        case .bloop: return "Bubble every \(Int(cooldown(l).rounded()))s"
        case .zip: return "\(Int(Pet.sparkDamage(l))) damage sparks, \(String(format: "%.1f", cooldown(l)))s apart"
        }
    }
}

extension SaveData {
    func ownsPet(_ p: Pet) -> Bool { p == .pip || ownedPets.contains(p.rawValue) }
    var pet: Pet? {
        guard let id = petID, let p = Pet(rawValue: id), ownsPet(p) else { return nil }
        return p
    }
    func petLevel(_ p: Pet) -> Int { Pet.level(xp: petXP[p.rawValue] ?? 0) }

    mutating func adoptPet(_ p: Pet) -> Bool {
        if ownsPet(p) { petID = p.rawValue; return true }
        guard coins >= p.price else { return false }
        coins -= p.price
        ownedPets.insert(p.rawValue)
        petID = p.rawValue
        return true
    }

    /// Gives the active pet run XP. Returns its new level when it leveled up.
    mutating func feedPet(_ xp: Int) -> Int? {
        guard let p = pet else { return nil }
        let before = petLevel(p)
        petXP[p.rawValue, default: 0] += xp
        let after = petLevel(p)
        return after > before ? after : nil
    }
}

/// The boss that last beat Nano. It comes back as an extra fight in a later city of the same
/// country (the city's own boss stays the same), a bit tougher each time it wins.
struct Nemesis: Codable, Equatable {
    var kind: String
    var variant: String
    var country: String
    var city: Int
    var wins = 1

    var setup: BossSetup {
        BossSetup(kind: EnemyKind(rawValue: kind) ?? .bossSumo, variant: BossVariant(rawValue: variant) ?? .normal)
    }
    var hpScale: Double { 1.2 + 0.15 * Double(wins - 1) }
    static let revengeCoins = 400
    static let revengeDNA = 3
    /// Seconds into the run when the Nemesis shows up.
    static let arrival: Double = 150
}

extension SaveData {
    /// Whether the Nemesis hunts this run: a campaign run in a later city of its country.
    func nemesisHunts(_ organ: Organ) -> Bool {
        guard let n = nemesis, !organ.isSideMode else { return false }
        return n.country == country.id && organ.infection > n.city
    }

    /// After a lost run: the boss that was on screen becomes (or stays) the Nemesis.
    mutating func recordDefeat(by setup: BossSetup, in organ: Organ) {
        guard !organ.isSideMode, setup.kind.isBoss, setup.kind != .bossVex else { return }
        if var n = nemesis {
            if n.kind == setup.kind.rawValue, n.country == country.id { n.wins += 1; n.city = max(n.city, organ.infection); nemesis = n }
            return
        }
        nemesis = Nemesis(kind: setup.kind.rawValue, variant: setup.variant.rawValue, country: country.id, city: organ.infection)
    }

    mutating func avengeNemesis() {
        nemesis = nil
        coins += Nemesis.revengeCoins
        bossDNA += Nemesis.revengeDNA
    }
}

/// Nano's best clear of an organ in a country, replayed as a see-through ghost.
struct Ghost: Codable, Equatable {
    static let interval = 0.25
    var time: Double            // seconds the clear took
    var xs: [Float]
    var ys: [Float]

    /// Position at a moment of the run (nil once the ghost's run is over).
    func position(at t: Double) -> (x: Double, y: Double)? {
        guard t <= time, !xs.isEmpty else { return nil }
        let f = t / Ghost.interval
        let i = min(xs.count - 1, Int(f))
        let j = min(xs.count - 1, i + 1)
        let k = f - Double(i)
        return (Double(xs[i]) + (Double(xs[j]) - Double(xs[i])) * k, Double(ys[i]) + (Double(ys[j]) - Double(ys[i])) * k)
    }
}

/// Ghosts live in their own small files, not in the save.
enum GhostStore {
    static func key(country: String, organ: Int) -> String { "\(country)-\(organ)" }
    private static var dir: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let d = base.appendingPathComponent("ghosts", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    static func load(_ key: String) -> Ghost? {
        guard let url = dir?.appendingPathComponent("\(key).json"), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Ghost.self, from: data)
    }
    /// Keeps the ghost only if it beats the stored one. Returns true when it is the new best.
    @discardableResult
    static func offer(_ g: Ghost, key: String) -> Bool {
        if let old = load(key), old.time <= g.time { return false }
        guard let url = dir?.appendingPathComponent("\(key).json"), let data = try? JSONEncoder().encode(g) else { return false }
        try? data.write(to: url, options: .atomic)
        return true
    }
}
