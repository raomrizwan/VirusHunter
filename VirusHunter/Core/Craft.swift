import Foundation

/// Craft Lab: bosses drop DNA, and DNA plus coins builds new weapons for the upgrade pool.
struct Recipe: Identifiable, Equatable {
    let weapon: WeaponKind
    let dna: Int
    let coins: Int
    var id: String { weapon.rawValue }
    var blurb: String {
        switch weapon {
        case .saw: return "Spinning plasma blades orbit Nano and shred anything close."
        case .rain: return "Antibodies rain down on random viruses around you."
        default: return ""
        }
    }

    static let all: [Recipe] = [
        Recipe(weapon: .saw, dna: 5, coins: 1_500),
        Recipe(weapon: .rain, dna: 8, coins: 2_500),
    ]
}

extension EnemyKind {
    /// Boss DNA dropped when this enemy is beaten.
    var dnaDrop: Int { isVillain || self == .bossVex ? 3 : isBoss ? 1 : 0 }
}

extension SaveData {
    func hasCrafted(_ w: WeaponKind) -> Bool { crafted.contains(w.rawValue) }
    func canCraft(_ r: Recipe) -> Bool { !hasCrafted(r.weapon) && bossDNA >= r.dna && coins >= r.coins }

    mutating func craft(_ r: Recipe) -> Bool {
        guard canCraft(r) else { return false }
        bossDNA -= r.dna
        coins -= r.coins
        crafted.insert(r.weapon.rawValue)
        return true
    }
}
