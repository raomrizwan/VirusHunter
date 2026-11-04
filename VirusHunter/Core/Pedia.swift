import Foundation

/// Virus-pedia: a card for every virus, mini boss and boss. Cards unlock the first time Nano meets
/// that character in a run (card id = its texture name).
struct PediaEntry: Identifiable, Equatable {
    enum Group: String, CaseIterable {
        case viruses = "Viruses", specials = "Special Viruses", strains = "City Strains"
        case minis = "Mini Bosses", bosses = "Bosses", variants = "Boss Variants"
    }
    let id: String
    let name: String
    let group: Group
    let line: String
}

enum Pedia {
    static let coinsPerCard = 10

    static let all: [PediaEntry] = {
        var out: [PediaEntry] = []
        for k in VirusStrain.kinds { out.append(PediaEntry(id: k.texture, name: k.pediaName, group: .viruses, line: k.pediaLine)) }
        for k in EnemyKind.specials { out.append(PediaEntry(id: k.texture, name: k.pediaName, group: .specials, line: k.pediaLine)) }
        for s in VirusStrain.allCases {
            for k in VirusStrain.kinds {
                out.append(PediaEntry(id: k.texture(strain: s), name: "\(s.name) \(k.pediaName)", group: .strains, line: s.pediaLine))
            }
        }
        for k in EnemyKind.miniBosses { out.append(PediaEntry(id: k.texture, name: k.miniTitle, group: .minis, line: k.pediaLine)) }
        for k in EnemyKind.bossRoster + [.bossVex] { out.append(PediaEntry(id: k.texture, name: k.bossTitle, group: .bosses, line: k.pediaLine)) }
        for k in EnemyKind.bossRoster {
            for v in BossVariant.twists {
                let b = BossSetup(kind: k, variant: v)
                out.append(PediaEntry(id: b.texture, name: b.title, group: .variants, line: v.detail))
            }
        }
        return out
    }()

    static func entry(_ id: String) -> PediaEntry? { all.first { $0.id == id } }
    static var ids: Set<String> { Set(all.map(\.id)) }
}

extension VirusStrain {
    var name: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    var pediaLine: String {
        switch self {
        case .horned: return "Grew horns to look scary. It worked."
        case .crystal: return "Frozen solid and sharp as glass."
        case .armored: return "Wears a helmet made from old cell walls."
        case .punk: return "Dyed its spikes green just for the outbreak."
        case .cyclops: return "One eye, twice the focus."
        case .zombie: return "Stitched back together by King Vex. Twice."
        case .gold: return "Thinks it is royalty. It is not."
        case .ninja: return "Silent, masked, and very rude."
        case .pirate: return "Arr! Steals healthy cells for treasure."
        }
    }
}

extension EnemyKind {
    var pediaName: String {
        switch self {
        case .spiky: return "Spiky"
        case .mini: return "Mini"
        case .blob: return "Blob"
        case .dart: return "Dart"
        case .spitter: return "Spitter"
        case .elite: return "Elite"
        case .bomber: return "Bomber"
        case .healer: return "Healer"
        case .sniper: return "Sniper"
        case .spore: return "Spore"
        default: return isMiniBoss ? miniTitle : bossTitle
        }
    }

    var pediaLine: String {
        switch self {
        case .spiky: return "The foot soldier of every outbreak. Never stops chasing."
        case .mini: return "Tiny, fast, and always in a gang."
        case .blob: return "Squishy and slow. Pop it and two minis spill out."
        case .dart: return "Waits... waits... then dashes like a rocket."
        case .spitter: return "Keeps its distance and spits slime. Rude."
        case .elite: return "A gold ring and a big ego. Drops a chest."
        case .bomber: return "Runs up close, flashes red, and goes BOOM. Lure it into a crowd."
        case .healer: return "Patches up other viruses. Always hit it first."
        case .sniper: return "Watch for the red line, then dodge."
        case .spore: return "Floats in weaving clouds, like dandelion seeds."
        case .miniQueen: return "Lays eggs full of minis. Bursts into spikies when beaten."
        case .miniTurret: return "Creeps forward and sprays four streams of slime."
        case .miniRhino: return "Charges three times in a row, then needs a nap."
        case .miniMagnet: return "Pulls Nano in close. Fight the pull!"
        case .bossSumo: return "Stomps the ground and shakes out minis."
        case .bossCowboy: return "Dashes fast and fires bullets in rings."
        case .bossRoyal: return "Hides behind shields and calls in soldiers."
        case .bossBrain: return "Spins psychic spirals and teleports next to you."
        case .bossMarrow: return "Throws bone spears. Gets faster when hurt."
        case .bossVex: return "The virus king himself. Enrages at half health."
        }
    }
}
