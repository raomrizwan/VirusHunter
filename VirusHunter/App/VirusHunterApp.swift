import SwiftUI

@main
struct VirusHunterApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model).preferredColorScheme(.dark)
        }
    }
}

/// App-wide state: saved progress and which screen is showing.
@MainActor
final class AppModel: ObservableObject {
    enum Screen: Equatable { case home, map, lab, skins, game(Organ) }

    @Published var save: SaveData
    @Published var screen: Screen

    static let args = ProcessInfo.processInfo.arguments
    static var uiTesting: Bool { args.contains("-uitesting") }

    init() {
        if AppModel.args.contains("-resetProgress") { UserDefaults.standard.removeObject(forKey: "vh2.save") }
        var s = SaveStore.shared.load()
        if AppModel.args.contains("-demoProgress") {
            s.coins = 2480; s.unlockedStage = 3; s.clearedStages = [1, 2]; s.seenIntro = true
            s.tech = ["power": 4, "health": 3, "speed": 2, "magnet": 3]
        }
        if AppModel.args.contains("-skipIntro") { s.seenIntro = true }
        // A brand-new player goes straight into the Lungs: menus come after they've had a taste of the game.
        let fresh = !s.seenIntro
        var first: Screen = fresh ? .game(Organ.all[0]) : .home
        s.seenIntro = true
        if let i = AppModel.args.firstIndex(of: "-startStage"), i + 1 < AppModel.args.count, let n = Int(AppModel.args[i + 1]) {
            first = .game(n == 0 ? .endless : Organ.all[max(0, min(4, n - 1))])
        }
        save = s
        screen = first
        if fresh { persist() } // the run reads the save from disk

    }

    func persist() { SaveStore.shared.save(save) }

    func go(_ s: Screen) { withAnimation(.easeInOut(duration: 0.3)) { screen = s } }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ZStack {
            switch model.screen {
            case .home: HomeView().transition(.opacity)
            case .map: MapView().transition(.move(edge: .trailing))
            case .lab: LabView().transition(.move(edge: .trailing))
            case .skins: SkinsView().transition(.move(edge: .trailing))
            case .game(let organ): GameView(organ: organ).transition(.opacity).id(organ.id)
            }
        }
        .onAppear {
            Sound.preload()
            if !AppModel.uiTesting { AdService.start() }
        }
    }
}
