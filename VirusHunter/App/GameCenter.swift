import GameKit
import UIKit

/// Game Center: sign-in, leaderboards and achievements. Everything is best-effort: if the player
/// isn't signed in (or the IDs aren't set up in App Store Connect yet) calls just do nothing.
@MainActor
enum GameCenter {
    enum Board: String, CaseIterable {
        case endless = "vh.leaderboard.endless"       // best Endless time, seconds
        case cities = "vh.leaderboard.cities"         // cities saved
        case kills = "vh.leaderboard.kills"           // total viruses destroyed
    }

    enum Achievement: String, CaseIterable {
        case firstBoss = "vh.ach.first_boss"
        case firstCity = "vh.ach.first_city"
        case fiveCities = "vh.ach.five_cities"
        case countrySaved = "vh.ach.country_saved"
        case evolved = "vh.ach.evolved"
        case streak7 = "vh.ach.streak7"
        case endless10 = "vh.ach.endless10"
        case kills10k = "vh.ach.kills10k"
    }

    static var enabled: Bool { GKLocalPlayer.local.isAuthenticated && !AppModel.uiTesting }

    /// Signs in quietly on launch; Apple shows its own sign-in sheet only when needed.
    static func authenticate() {
        guard !AppModel.uiTesting else { return }
        GKLocalPlayer.local.authenticateHandler = { vc, _ in
            Task { @MainActor in if let vc { topController()?.present(vc, animated: true) } }
        }
    }

    /// Sends what the save shows so far: scores only ever go up, so resending is harmless.
    static func sync(_ save: SaveData) {
        guard enabled else { return }
        let scores: [(Board, Int)] = [(.endless, Int(save.bestEndless)), (.cities, save.citiesCleared), (.kills, save.totalKills)]
        for (b, v) in scores where v > 0 {
            GKLeaderboard.submitScore(v, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [b.rawValue]) { _ in }
        }
        var done: [Achievement] = []
        if save.clearedStages.contains(1) { done.append(.firstBoss) }
        if save.citiesCleared >= 1 { done.append(.firstCity) }
        if save.citiesCleared >= 5 { done.append(.fiveCities) }
        if save.citiesCleared >= Organ.maxInfection { done.append(.countrySaved) }
        if save.everEvolved { done.append(.evolved) }
        if save.daily.streak >= 7 { done.append(.streak7) }
        if save.bestEndless >= 600 { done.append(.endless10) }
        if save.totalKills >= 10_000 { done.append(.kills10k) }
        let list = done.map { a -> GKAchievement in
            let g = GKAchievement(identifier: a.rawValue); g.percentComplete = 100; g.showsCompletionBanner = true; return g
        }
        if !list.isEmpty { GKAchievement.report(list) { _ in } }
    }

    /// Apple's Game Center screen (leaderboards + achievements).
    static func showDashboard() {
        guard enabled else { authenticate(); return }
        let vc = GKGameCenterViewController(state: .leaderboards)
        vc.gameCenterDelegate = Dismisser.shared
        topController()?.present(vc, animated: true)
    }

    private static func topController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let p = top?.presentedViewController { top = p }
        return top
    }

    private final class Dismisser: NSObject, GKGameCenterControllerDelegate {
        static let shared = Dismisser()
        func gameCenterViewControllerDidFinish(_ vc: GKGameCenterViewController) { vc.dismiss(animated: true) }
    }
}
