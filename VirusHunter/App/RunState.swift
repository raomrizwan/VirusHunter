import SwiftUI

/// Bridge between the SpriteKit simulation and the SwiftUI HUD/overlays.
@MainActor
final class RunState: ObservableObject {
    enum Phase: Equatable {
        case playing
        case levelUp([UpgradeOption], fromChest: Bool)
        case paused
        case dead(canRevive: Bool)
        case finished(won: Bool)
    }

    let organ: Organ
    @Published var phase: Phase = .playing
    @Published var time: Double = 0
    @Published var level = 1
    @Published var xpFraction: Double = 0
    @Published var hpFraction: Double = 1
    @Published var kills = 0
    @Published var coins = 0
    @Published var bossName: String?
    @Published var bossHP: Double = 0
    @Published var banner: String?
    @Published var loadout = Loadout()
    @Published var revivesUsed = 0
    /// "Drag anywhere to fly" hint on the first run, hidden at the first touch.
    @Published var moveHint = false

    /// Set by the scene; the HUD calls these.
    var onChoose: ((UpgradeOption) -> Void)?
    var onResume: (() -> Void)?
    var onRevive: (() -> Void)?

    init(organ: Organ) { self.organ = organ }

    func flash(_ text: String, seconds: Double = 2) {
        banner = text
        let t = text
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            if self?.banner == t { self?.banner = nil }
        }
    }

    var timeText: String {
        let s = Int(time)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
