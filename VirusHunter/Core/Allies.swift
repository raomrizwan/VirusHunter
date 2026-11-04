import Foundation

/// Dr. Leuko's white blood cell allies: one flies with Nano in every run.
enum Ally: String, CaseIterable, Identifiable {
    case medic, guardian, hunter

    var id: String { rawValue }
    var title: String {
        switch self {
        case .medic: return "Medic Cell"
        case .guardian: return "Guardian Cell"
        case .hunter: return "Hunter Cell"
        }
    }
    var detail: String {
        switch self {
        case .medic: return "Heals Nano a little every few seconds."
        case .guardian: return "Wipes out nearby enemy shots and pushes viruses back."
        case .hunter: return "Zaps the nearest virus again and again."
        }
    }
    var texture: String { "ally-\(rawValue)" }
    /// Coins to recruit (the Medic joins for free once the first city is saved).
    var price: Int {
        switch self {
        case .medic: return 0
        case .guardian: return 2_500
        case .hunter: return 4_000
        }
    }
    /// Seconds between the ally's actions.
    var cooldown: Double {
        switch self {
        case .medic: return 5
        case .guardian: return 3
        case .hunter: return 0.8
        }
    }
}

extension SaveData {
    func ownsAlly(_ a: Ally) -> Bool { a == .medic ? citiesCleared >= 1 || ownedAllies.contains(a.rawValue) : ownedAllies.contains(a.rawValue) }

    /// The ally flying with Nano (nil = none recruited or picked).
    var ally: Ally? {
        guard let id = allyID, let a = Ally(rawValue: id), ownsAlly(a) else { return nil }
        return a
    }

    mutating func recruitAlly(_ a: Ally) -> Bool {
        guard !ownsAlly(a) else { allyID = a.rawValue; return true }
        guard a != .medic, coins >= a.price else { return false }
        coins -= a.price
        ownedAllies.insert(a.rawValue)
        allyID = a.rawValue
        return true
    }
}
