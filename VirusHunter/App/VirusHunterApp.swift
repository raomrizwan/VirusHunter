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
    enum Screen: Equatable { case home, map, lab, skins, daily, game(Organ) }

    @Published var save: SaveData
    @Published var screen: Screen
    @Published var story: ActiveStory?
    @Published var pickingCountry = false

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
        s.daily.refresh()
        save = s
        screen = first
        if fresh { persist() } // the run reads the save from disk

    }

    func persist() { SaveStore.shared.save(save) }

    /// New day while the app stayed open or in the background: roll the missions and streak over.
    func refreshDaily() {
        var d = save.daily
        d.refresh()
        if d != save.daily { save.daily = d; persist() }
    }

    func go(_ s: Screen) { withAnimation(.easeInOut(duration: 0.3)) { screen = s } }

    /// Starts a run, showing the organ's story intro first when there is one.
    func play(_ organ: Organ) {
        if let s = Story.intro(for: organ, save: save), !AppModel.uiTesting {
            showStory(s) { [weak self] in self?.go(.game(organ)) }
        } else {
            go(.game(organ))
        }
    }

    /// Shows a story scene (marked as seen right away, so skipping or quitting never repeats it).
    func showStory(_ scene: StoryScene, then: (() -> Void)? = nil) {
        guard !AppModel.uiTesting else { then?(); return }
        save.seenStory.insert(scene.id)
        persist()
        withAnimation { story = ActiveStory(scene: scene, onDone: then) }
    }

    /// Replays a seen scene from the Story journal.
    func replayStory(_ scene: StoryScene) {
        let s = Story.resolve(scene, country: save.country, city: Story.city(for: scene.id))
        withAnimation { story = ActiveStory(scene: s, onDone: nil) }
    }

    func closeStory() {
        let done = story?.onDone
        withAnimation { story = nil }
        done?()
    }

    /// The active city's arrival scene, shown when the Body Map opens.
    func checkMapStory() {
        guard screen == .map, story == nil, save.countryCode != nil, let s = Story.mapScene(save: save) else { return }
        showStory(s)
    }

    func setCountry(_ code: String) {
        save.countryCode = code
        persist()
        withAnimation { pickingCountry = false }
        checkMapStory()
    }

    /// Ask for the country once the player reaches the menus (a fresh install starts straight in a run).
    var needsCountry: Bool {
        if case .game = screen { return false }
        return save.countryCode == nil && !AppModel.uiTesting
    }
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
            case .daily: DailyView().transition(.move(edge: .trailing))
            case .game(let organ): GameView(organ: organ).transition(.opacity).id("\(organ.id)-\(organ.infection)")
            }
            if model.needsCountry || model.pickingCountry {
                CountryPicker().transition(.opacity).zIndex(5)
            }
            if let st = model.story {
                StoryView(story: st) { model.closeStory() }.id(st.id).transition(.opacity).zIndex(10)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in model.refreshDaily() }
        .onAppear {
            Sound.preload()
            if !AppModel.uiTesting { AdService.start() }
        }
    }
}
