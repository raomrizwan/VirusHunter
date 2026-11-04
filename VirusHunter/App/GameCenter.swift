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
        case bossRush = "vh.leaderboard.bossrush"     // this week's best Boss Rush time, seconds (lower is better)
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
        var scores: [(Board, Int)] = [(.endless, Int(save.bestEndless)), (.cities, save.citiesCleared), (.kills, save.totalKills)]
        if let rush = save.bossRushBest() { scores.append((.bossRush, Int(rush.rounded(.up)))) }
        for (b, v) in scores where v > 0 {
            GKLeaderboard.submitScore(v, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [b.rawValue]) { _ in }
        }
        // Every in-game trophy is mirrored as a Game Center achievement "vh.ach.<trophy>".
        let list = Trophy.allCases.filter { $0.done(save) }.map { t -> GKAchievement in
            let g = GKAchievement(identifier: "vh.ach.\(t.rawValue)"); g.percentComplete = 100; g.showsCompletionBanner = true; return g
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
        // GameKit calls this on the main thread.
        nonisolated func gameCenterViewControllerDidFinish(_ vc: GKGameCenterViewController) {
            MainActor.assumeIsolated { vc.dismiss(animated: true) }
        }
    }
}
