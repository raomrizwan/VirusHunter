import SwiftUI
import SpriteKit

@MainActor
final class GameHolder: ObservableObject {
    let state: RunState
    let scene: GameScene
    let autoplay: Bool
    init(organ: Organ, save: SaveData) {
        let args = ProcessInfo.processInfo.arguments
        autoplay = args.contains("-autoplay")
        state = RunState(organ: organ)
        if args.contains("-demoLoadout") {
            state.loadout = Loadout(weapons: [.laser: 4, .swarm: 5, .shield: 3, .zap: 3], weaponOrder: [.laser, .swarm, .shield, .zap], passives: [.power: 3, .magnet: 2])
        }
        scene = GameScene(size: UIScreen.main.bounds.size, state: state, save: save, autoplay: autoplay, god: args.contains("-god"))
        if let i = args.firstIndex(of: "-startTime"), i + 1 < args.count, let t = Double(args[i + 1]) { scene.fastForward(to: t) }
    }
}

struct GameView: View {
    let organ: Organ
    @StateObject private var holder: GameHolder
    init(organ: Organ) {
        self.organ = organ
        _holder = StateObject(wrappedValue: GameHolder(organ: organ, save: SaveStore.shared.load()))
    }
    var body: some View { GameContent(organ: organ, holder: holder, state: holder.state) }
}

struct GameContent: View {
    @EnvironmentObject var model: AppModel
    let organ: Organ
    let holder: GameHolder
    @ObservedObject var state: RunState
    @State private var reward: (coins: Int, doubled: Bool)?
    @State private var saved = false

    var body: some View {
        let st = state
        ZStack {
            SpriteView(scene: holder.scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
            HUD(state: st, onPause: { holder.scene.pauseRun() })
            overlay(st)
        }
        .statusBarHidden(true)
        .onChange(of: st.phase) { _, p in
            if case .finished(let won) = p { finish(won: won) }
            if holder.autoplay, case .levelUp(let opts, _) = p {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { if case .levelUp = st.phase { st.onChoose?(opts[0]) } }
            }
        }
    }

    @ViewBuilder private func overlay(_ st: RunState) -> some View {
        switch st.phase {
        case .playing: EmptyView()
        case .levelUp(let opts, let chest): LevelUpView(options: opts, fromChest: chest, loadout: st.loadout) { st.onChoose?($0) }
        case .paused: PauseView(state: st, onResume: { st.onResume?() }, onQuit: { holder.scene.giveUp() })
        case .dead(let canRevive): DeadView(canRevive: canRevive, freeRevive: model.save.level(.revive) > 0 && st.revivesUsed == 0,
                                            onRevive: revive, onGiveUp: { holder.scene.giveUp() })
        case .finished(let won): ResultView(organ: organ, won: won, state: st, reward: reward, onDouble: doubleCoins, onDone: leave, onNext: nextOrgan)
        }
    }

    private func revive() {
        let st = holder.state
        if model.save.level(.revive) > 0 || !RewardedController.shared.isReady || AppModel.uiTesting {
            st.onRevive?()
        } else {
            RewardedController.shared.show { earned in if earned { st.onRevive?() } else { holder.scene.giveUp() } }
        }
    }

    private func finish(won: Bool) {
        guard !saved else { return }
        saved = true
        let r = holder.scene.result
        let stats = PlayerStats.make(save: model.save, loadout: Loadout())
        let coins = runCoins(collected: r.coins, kills: r.kills, cleared: won ? organ : nil, bonus: stats.coinBonus)
        var s = model.save
        s.coins += coins
        s.runs += 1
        s.totalKills += r.kills
        if won, !organ.isEndless {
            s.clearedStages.insert(organ.id)
            s.unlockedStage = max(s.unlockedStage, min(5, organ.id + 1))
        }
        if organ.isEndless { s.bestEndless = max(s.bestEndless, r.time) }
        model.save = s
        model.persist()
        reward = (coins, false)
    }

    private func doubleCoins() {
        guard let r = reward, !r.doubled else { return }
        let apply = {
            model.save.coins += r.coins
            model.persist()
            reward = (r.coins * 2, true)
            Sound.coin.play(); Haptics.success()
        }
        if AppModel.uiTesting { apply(); return }
        RewardedController.shared.show { earned in if earned { apply() } }
    }

    private func leave() {
        InterstitialController.shared.showIfAllowed(gamesPlayed: model.save.runs) { model.go(organ.isEndless ? .home : .map) }
    }

    private func nextOrgan() {
        let next = Organ.all[min(4, organ.id)]
        InterstitialController.shared.showIfAllowed(gamesPlayed: model.save.runs) { model.go(.game(next)) }
    }
}

// MARK: - HUD

struct HUD: View {
    @ObservedObject var state: RunState
    var onPause: () -> Void
    var body: some View {
        VStack(spacing: 6) {
            // XP bar
            HStack(spacing: 8) {
                Text("LV \(state.level)").font(Theme.body(14, .black)).foregroundStyle(.white)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Capsule().fill(LinearGradient(colors: [Theme.cyan, Color(red: 0.2, green: 0.5, blue: 1)], startPoint: .top, endPoint: .bottom)))
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.black.opacity(0.45))
                        Capsule().fill(LinearGradient(colors: [Theme.cyan, Color(red: 0.55, green: 1, blue: 1)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(8, g.size.width * state.xpFraction))
                            .shadow(color: Theme.cyan.opacity(0.8), radius: 6)
                    }
                }
                .frame(height: 12)
                Button(action: onPause) {
                    Image(systemName: "pause.fill").font(.system(size: 16, weight: .black)).foregroundStyle(.white).frame(width: 38, height: 38).glass(12)
                }
                .accessibilityIdentifier("pauseButton")
            }
            HStack {
                Label("\(state.kills)", systemImage: "scope").font(Theme.body(15, .heavy)).foregroundStyle(.white)
                Spacer()
                Text(state.timeText).font(Theme.title(26)).foregroundStyle(.white).monospacedDigit().shadow(color: .black.opacity(0.6), radius: 3)
                Spacer()
                HStack(spacing: 4) { Image("coin").resizable().frame(width: 18, height: 18); Text("\(state.coins)").font(Theme.body(15, .heavy)).foregroundStyle(.white).monospacedDigit() }
            }
            .padding(.horizontal, 4)
            HStack(spacing: 6) {
                ForEach(state.loadout.weaponOrder, id: \.self) { w in
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: w.symbol).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.cyan).frame(width: 30, height: 30).background(RoundedRectangle(cornerRadius: 9).fill(.black.opacity(0.4)))
                        Text("\(state.loadout.level(w))").font(Theme.body(9, .black)).foregroundStyle(.white).padding(2).background(Circle().fill(Theme.magenta)).offset(x: 3, y: 3)
                    }
                }
                Spacer()
            }
            if let name = state.bossName {
                VStack(spacing: 3) {
                    Text(name.uppercased()).font(Theme.body(13, .black)).foregroundStyle(Theme.red).tracking(2)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.black.opacity(0.5))
                            Capsule().fill(LinearGradient(colors: [Theme.red, Color(red: 1, green: 0.55, blue: 0.3)], startPoint: .leading, endPoint: .trailing)).frame(width: g.size.width * state.bossHP)
                        }
                    }
                    .frame(height: 10)
                }
                .padding(.horizontal, 30).transition(.opacity)
            }
            Spacer()
            if let b = state.banner {
                Text(b).font(Theme.title(24)).foregroundStyle(.white).multilineTextAlignment(.center)
                    .padding(.horizontal, 22).padding(.vertical, 12).glass(18)
                    .shadow(color: Theme.magenta.opacity(0.5), radius: 12)
                    .transition(.scale.combined(with: .opacity))
                Spacer()
            }
        }
        .padding(.horizontal, 14).padding(.top, 8)
        .animation(.spring(duration: 0.35), value: state.banner)
        .animation(.easeInOut, value: state.bossName)
    }
}

// MARK: - Level up

struct LevelUpView: View {
    let options: [UpgradeOption]
    let fromChest: Bool
    let loadout: Loadout
    var choose: (UpgradeOption) -> Void
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(fromChest ? "SUPPLY CHEST!" : "LEVEL UP!")
                    .font(Theme.title(40)).foregroundStyle(LinearGradient(colors: [.white, Theme.gold], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Theme.gold.opacity(0.7), radius: 14)
                    .scaleEffect(appear ? 1 : 0.6)
                Text("Choose an upgrade").font(Theme.body(15)).foregroundStyle(Theme.muted)
                ForEach(Array(options.enumerated()), id: \.element.id) { i, o in
                    Button { choose(o) } label: { card(o) }
                        .buttonStyle(PressStyle())
                        .accessibilityIdentifier("upgrade\(i)")
                        .offset(y: appear ? 0 : 60).opacity(appear ? 1 : 0)
                        .animation(.spring(duration: 0.45).delay(0.06 * Double(i)), value: appear)
                }
            }
            .padding(.horizontal, 22)
        }
        .onAppear { withAnimation(.spring(duration: 0.4)) { appear = true } }
    }

    private func card(_ o: UpgradeOption) -> some View {
        let (icon, title, tag, detail, color): (String, String, String, String, Color) = {
            switch o {
            case .weapon(let w, let l): return (w.symbol, w.title, l == 1 ? "NEW!" : "LV \(l)", w.detail(nextLevel: l), Theme.cyan)
            case .passive(let p, let l): return (p.symbol, p.title, l == 1 ? "NEW!" : "LV \(l)", p.detail, Theme.magenta)
            case .heal: return ("heart.fill", "Full Repair", "", "Restore all health.", Theme.lime)
            case .coins(let n): return ("bitcoinsign.circle.fill", "Bio-Coins", "+\(n)", "Extra coins for the Tech Lab.", Theme.gold)
            }
        }()
        return HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 28, weight: .bold)).foregroundStyle(color)
                .frame(width: 62, height: 62).background(RoundedRectangle(cornerRadius: 16).fill(color.opacity(0.18)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.6), lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).font(Theme.body(19, .heavy)).foregroundStyle(.white)
                    if !tag.isEmpty {
                        Text(tag).font(Theme.body(11, .black)).foregroundStyle(tag == "NEW!" ? .black : .white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(tag == "NEW!" ? Theme.gold : color.opacity(0.5)))
                    }
                }
                Text(detail).font(Theme.body(14, .medium)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .glass(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.5), lineWidth: 1.5))
    }
}

// MARK: - Pause / dead / result

struct PauseView: View {
    @ObservedObject var state: RunState
    var onResume: () -> Void
    var onQuit: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("PAUSED").font(Theme.title(40)).foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(state.loadout.weaponOrder, id: \.self) { w in
                        Label("\(w.title)  ·  LV \(state.loadout.level(w))", systemImage: w.symbol).font(Theme.body(16)).foregroundStyle(.white)
                    }
                    ForEach(PassiveKind.allCases.filter { state.loadout.level($0) > 0 }) { p in
                        Label("\(p.title)  ·  LV \(state.loadout.level(p))", systemImage: p.symbol).font(Theme.body(15)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading).glass()
                GameButton(title: "Resume", icon: "play.fill", action: onResume).accessibilityIdentifier("resumeButton")
                GameButton(title: "Quit run", icon: "xmark", colors: [Color(white: 0.45), Color(white: 0.25)], height: 52, action: onQuit)
            }
            .padding(.horizontal, 30)
        }
    }
}

struct DeadView: View {
    let canRevive: Bool
    let freeRevive: Bool
    var onRevive: () -> Void
    var onGiveUp: () -> Void
    @State private var count = 9
    var body: some View {
        ZStack {
            Color(red: 0.2, green: 0, blue: 0.05).opacity(0.75).ignoresSafeArea()
            VStack(spacing: 18) {
                Image("nano-hurt").resizable().scaledToFit().frame(width: 150)
                Text("NANO IS DOWN!").font(Theme.title(36)).foregroundStyle(.white)
                if canRevive {
                    Text("\(count)").font(Theme.title(56)).foregroundStyle(Theme.gold).contentTransition(.numericText())
                    GameButton(title: freeRevive ? "Revive (free)" : "Revive", icon: freeRevive ? "arrow.counterclockwise" : "play.rectangle.fill",
                               colors: [Theme.gold, Color(red: 0.95, green: 0.5, blue: 0.1)], action: onRevive)
                        .accessibilityIdentifier("reviveButton")
                }
                Button("No thanks") { onGiveUp() }.font(Theme.body(17)).foregroundStyle(Theme.muted).padding(.top, 4)
                    .accessibilityIdentifier("giveUpButton")
            }
            .padding(.horizontal, 30)
        }
        .task {
            guard canRevive else { return }
            while count > 0 {
                try? await Task.sleep(for: .seconds(1))
                withAnimation { count -= 1 }
            }
            onGiveUp()
        }
    }
}

struct ResultView: View {
    let organ: Organ
    let won: Bool
    @ObservedObject var state: RunState
    let reward: (coins: Int, doubled: Bool)?
    var onDouble: () -> Void
    var onDone: () -> Void
    var onNext: () -> Void
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(won ? "nano-joy" : "nano-hurt").resizable().scaledToFit().frame(width: 150)
                    .scaleEffect(appear ? 1 : 0.5).rotationEffect(.degrees(appear ? 0 : -20))
                Text(won ? "\(organ.name.uppercased()) CLEARED!" : organ.isEndless ? "YOU SURVIVED" : "INFECTED!")
                    .font(Theme.title(32)).foregroundStyle(won ? Theme.lime : .white).multilineTextAlignment(.center)
                HStack(spacing: 10) {
                    stat("Time", state.timeText, "clock.fill")
                    stat("Kills", "\(state.kills)", "scope")
                    stat("Level", "\(state.level)", "arrow.up.circle.fill")
                }
                if let r = reward {
                    HStack(spacing: 8) {
                        Image("coin").resizable().frame(width: 34, height: 34)
                        Text("+\(r.coins)").font(Theme.title(38)).foregroundStyle(Theme.gold).monospacedDigit().contentTransition(.numericText())
                    }
                    .padding(.vertical, 4)
                    if !r.doubled && r.coins > 0 {
                        GameButton(title: "Double coins", icon: "play.rectangle.fill", colors: [Theme.gold, Color(red: 0.95, green: 0.5, blue: 0.1)], height: 56, action: onDouble)
                            .accessibilityIdentifier("doubleButton")
                    }
                }
                if won && !organ.isEndless && organ.id < 5 {
                    GameButton(title: "Next organ", icon: "arrow.right", action: onNext).accessibilityIdentifier("nextButton")
                }
                GameButton(title: "Continue", colors: [Color(white: 0.5), Color(white: 0.28)], height: 52, action: onDone)
                    .accessibilityIdentifier("continueButton")
            }
            .padding(.horizontal, 28)
        }
        .onAppear { withAnimation(.spring(duration: 0.6, bounce: 0.4)) { appear = true } }
    }

    private func stat(_ t: String, _ v: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.cyan)
            Text(v).font(Theme.body(20, .heavy)).foregroundStyle(.white).monospacedDigit()
            Text(t).font(Theme.body(12)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12).glass(16)
    }
}
