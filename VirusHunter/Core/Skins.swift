import Foundation

/// Nano's look. Classic is free; the rest are bought with Bio-Coins or earned by clearing an organ.
enum Skin: String, CaseIterable, Codable, Identifiable {
    case classic, neon, toxic, stealth, gold
    var id: String { rawValue }

    enum Pose: String { case happy, fight, joy, hurt }

    var title: String {
        switch self {
        case .classic: return "Classic Nano"
        case .neon: return "Neon Nano"
        case .toxic: return "Toxic Nano"
        case .stealth: return "Stealth Nano"
        case .gold: return "Golden Nano"
        }
    }

    /// Asset names: classic keeps the original art ("nano-fight"), others are "nano-gold-fight".
    func texture(_ pose: Pose) -> String { self == .classic ? "nano-\(pose.rawValue)" : "nano-\(rawValue)-\(pose.rawValue)" }
    var botTexture: String { self == .classic ? "minibot" : "minibot-\(rawValue)" }

    /// Coin price, nil when the skin is earned another way.
    var price: Int? {
        switch self {
        case .classic: return 0
        case .neon: return 250
        case .toxic: return 600
        case .stealth: return 1200
        case .gold: return nil
        }
    }
    /// Organ that unlocks the skin when cleared.
    var clearStage: Int? { self == .gold ? 3 : nil }

    var howToGet: String {
        if let p = price { return p == 0 ? "Free" : "\(p) Bio-Coins" }
        if let s = clearStage { return "Clear the \(Organ.all[s - 1].name)" }
        return ""
    }
}

extension SaveData {
    var skin: Skin { Skin(rawValue: skinID) ?? .classic }

    func owns(_ s: Skin) -> Bool {
        if s == .classic || ownedSkins.contains(s.rawValue) { return true }
        if let st = s.clearStage { return clearedStages.contains(st) }
        return false
    }

    mutating func buy(_ s: Skin) -> Bool {
        guard !owns(s), let p = s.price, coins >= p else { return false }
        coins -= p
        ownedSkins.insert(s.rawValue)
        return true
    }

    /// Drives the dot on the Home "Skins" button.
    var canAffordNewSkin: Bool { Skin.allCases.contains { !owns($0) && ($0.price ?? .max) <= coins } }

    mutating func equip(_ s: Skin) { if owns(s) { skinID = s.rawValue } }

    /// The next thing to save up for, shown after a run: the cheapest skin still locked, else the cheapest Tech Lab upgrade.
    var nextGoal: (title: String, image: String?, symbol: String?, cost: Int)? {
        if let s = Skin.allCases.filter({ !owns($0) && $0.price != nil }).min(by: { $0.price! < $1.price! }) {
            return (s.title, s.texture(.happy), nil, s.price!)
        }
        let open = TechKind.allCases.filter { level($0) < $0.maxLevel }
        if let t = open.min(by: { $0.cost(toLevel: level($0) + 1) < $1.cost(toLevel: level($1) + 1) }) {
            return ("\(t.title) Lv \(level(t) + 1)", nil, t.symbol, t.cost(toLevel: level(t) + 1))
        }
        return nil
    }
}

// MARK: - First run

/// The very first run is tuned so a new player gets strong fast: quicker early level-ups,
/// a damage boost and Nano Swarm offered on the first level-up.
enum Rookie {
    static let damageBoost = 1.25
    static let freeLevels = 6

    static func xpNeeded(_ level: Int) -> Int {
        let full = xpToNext(level)
        return level < freeLevels ? max(3, full / 2) : full
    }

    /// Puts Nano Swarm first in the first level-up's choices if the player doesn't have it yet.
    static func featureSwarm(_ options: [UpgradeOption], loadout: Loadout) -> [UpgradeOption] {
        guard loadout.level(.swarm) == 0, loadout.weapons.count < maxWeapons else { return options }
        let swarm = UpgradeOption.weapon(.swarm, toLevel: 1)
        var rest = options.filter { $0 != swarm }
        if rest.count >= options.count { rest.removeLast() }
        return [swarm] + rest
    }
}
