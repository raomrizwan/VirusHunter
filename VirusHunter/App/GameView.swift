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
    @State private var unlocks: [String] = []
    @State private var saved = false

    var body: some View {
        let st = state
        ZStack {
            SpriteView(scene: holder.scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
            HUD(state: st, onPause: { holder.scene.pauseRun() })
            if st.moveHint && st.phase == .playing { MoveHint().transition(.opacity) }
            overlay(st)
        }
        .statusBarHidden(true)
        .onAppear {
            // The Vaccine Lab boost lasts for one run (the scene already read it).
            if model.save.labBoost > 0 { model.save.labBoost = 0; model.persist() }
        }
        .animation(.easeOut(duration: 0.3), value: st.moveHint)
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
        case .dead(let canRevive): DeadView(skin: model.save.skin, canRevive: canRevive, freeRevive: model.save.level(.revive) > 0 && st.revivesUsed == 0,
                                            onRevive: revive, onGiveUp: { holder.scene.giveUp() })
        case .finished(let won): ResultView(organ: organ, won: won, state: st, reward: reward, save: model.save, unlocks: unlocks,
                                            onDouble: doubleCoins, onDone: leave, onNext: nextMission,
                                            onVaccine: { model.save.labBoost = $0; model.persist() })
        }
    }

    private func revive() {
        let st = holder.state
        guard case .dead(canRevive: true) = st.phase else { return }
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
        let coins = runCoins(collected: r.coins, kills: r.kills, cleared: won ? organ : nil, bonus: stats.coinBonus * organ.coinScale)
        var s = model.save
        let before = s
        s.coins += coins
        s.runs += 1
        s.totalKills += r.kills
        if won { s.recordClear(organ) }
        if s.citiesCleared > before.citiesCleared, case .coins(let n) = CityReward.forCity(s.citiesCleared) { s.coins += n }
        let scene = won ? Story.afterWin(organ, before: model.save, after: s) : nil
        if organ.isEndless { s.bestEndless = max(s.bestEndless, r.time) }
        // Virus-pedia: new cards pay a few coins each.
        let newCards = holder.scene.seen.intersection(Pedia.ids).subtracting(s.discovered)
        s.discovered.formUnion(newCards)
        s.coins += newCards.count * Pedia.coinsPerCard
        s.bestCombo = max(s.bestCombo, r.combo)
        let dna = holder.scene.dnaEarned
        s.bossDNA += dna
        // Season Pass XP and today's Outbreak Alert bonus
        s.refreshSeason()
        let tierBefore = s.seasonTier
        s.seasonXP += Season.runXP(kills: r.kills, bosses: r.bosses, seconds: r.time, won: won)
        let newTiers = s.seasonTier - tierBefore
        let alertPaid = won && s.claimAlert(organ, alert: before.outbreakAlert())
        var rushLine: String?
        if organ.isBossRush, won {
            let week = BossRush.week()
            let first = s.bossRushBests[week] == nil
            s.bossRushBests[week] = min(s.bossRushBests[week] ?? .infinity, r.time)
            let bonus = first ? BossRush.firstWinReward : BossRush.replayReward
            s.coins += bonus
            rushLine = "Boss Rush beaten in \(timeString(r.time))! +\(bonus) coins"
        }
        s.goldenCaught += r.golden
        if holder.state.loadout.weapons.values.contains(where: { $0 >= evolvedLevel }) { s.everEvolved = true }
        s.daily.refresh()
        s.daily.record(RunReport(kills: r.kills, bosses: r.bosses, cleared: won && !organ.isSideMode, seconds: r.time,
                                 coins: r.coins, level: r.level, endless: organ.isEndless))
        model.save = s
        model.persist()
        GameCenter.sync(s)
        unlocks = newUnlocks(before: before, after: s)
        if let rushLine { unlocks.insert(rushLine, at: 0) }
        if dna > 0 { unlocks.append("🧬 +\(dna) Boss DNA for the Craft Lab") }
        if alertPaid { unlocks.insert("🚨 Outbreak Alert contained! +\(OutbreakAlert.coinBonus) coins, +\(OutbreakAlert.dnaBonus) Boss DNA", at: 0) }
        if newTiers > 0 { unlocks.append("🎟️ Season Pass tier \(s.seasonTier) reached") }
        if !newCards.isEmpty { unlocks.append("📖 \(newCards.count) new Virus-pedia card\(newCards.count == 1 ? "" : "s") (+\(newCards.count * Pedia.coinsPerCard) coins)") }
        if s.citiesCleared >= 1, before.citiesCleared == 0 { unlocks.append("Medic Cell ally and Boss Rush unlocked") }
        reward = (coins, false)
        if let scene { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { model.showStory(scene) } }
    }

    /// Lines like "Heart unlocked" for the result screen, so the player sees what this run opened up.
    private func newUnlocks(before: SaveData, after: SaveData) -> [String] {
        var out: [String] = []
        if after.unlockedStage > before.unlockedStage { out.append("\(Organ.all[after.unlockedStage - 1].name) unlocked") }
        if after.endlessUnlocked && !before.endlessUnlocked { out.append("Endless mode unlocked") }
        if !organ.isSideMode {
            let cured = before.infected(inCity: organ.infection) - after.infected(inCity: organ.infection)
            if cured > 0 { out.append("\(cured.formatted()) people cured in \(after.country.city(organ.infection))") }
        }
        if after.citiesCleared > before.citiesCleared {
            out.append("\(after.country.city(after.citiesCleared)) saved!")
            out.append("🎁 " + CityReward.forCity(after.citiesCleared).title)
            if after.citiesCleared < Organ.maxInfection { out.append("Outbreak in \(after.country.city(after.currentCity)) unlocked") }
        }
        for k in Skin.allCases where after.owns(k) && !before.owns(k) { out.append("\(k.title) unlocked") }
        for m in after.daily.missions where m.done && !(before.daily.missions.first { $0.id == m.id }?.done ?? false) {
            out.append("Daily mission done: \(m.title)")
        }
        return out
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
        InterstitialController.shared.showIfAllowed(gamesPlayed: model.save.runs) { model.go(organ.isSideMode ? .home : .map) }
    }

    /// The next organ to clear in the active city (or the first one in the next city).
    private func nextMission() {
        guard let next = model.save.nextMission else { leave(); return }
        InterstitialController.shared.showIfAllowed(gamesPlayed: model.save.runs) { model.play(next) }
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
                        Text(state.loadout.level(w) >= evolvedLevel ? "★" : "\(state.loadout.level(w))").font(Theme.body(9, .black)).foregroundStyle(.white).padding(2).background(Circle().fill(Theme.magenta)).offset(x: 3, y: 3)
                    }
                }
                Spacer()
                if state.combo >= 10 {
                    Text("COMBO x\(state.combo)").font(Theme.title(16)).foregroundStyle(Theme.gold)
                        .shadow(color: Theme.gold.opacity(0.7), radius: 6)
                        .accessibilityIdentifier("combo")
                }
                if let o = state.objective {
                    Label(o, systemImage: state.objectiveDone ? "checkmark.circle.fill" : "target")
                        .font(Theme.body(11, .heavy)).foregroundStyle(state.objectiveDone ? Theme.lime : Theme.gold)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.horizontal, 8).padding(.vertical, 5).background(Capsule().fill(.black.opacity(0.45)))
                        .accessibilityIdentifier("objective")
                }
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
            case .weapon(let w, let l) where l >= evolvedLevel: return (w.symbol, w.evolvedTitle, "EVOLVE", w.detail(nextLevel: l), Theme.gold)
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
                        Label(state.loadout.level(w) >= evolvedLevel ? "\(w.evolvedTitle)  ·  EVOLVED" : "\(w.title)  ·  LV \(state.loadout.level(w))", systemImage: w.symbol).font(Theme.body(16)).foregroundStyle(.white)
                    }
                    ForEach(PassiveKind.allCases.filter { state.loadout.level($0) > 0 }) { p in
                        Label("\(p.title)  ·  LV \(state.loadout.level(p))", systemImage: p.symbol).font(Theme.body(15)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading).glass()
                GameButton(title: "Resume", icon: "play.fill", action: onResume).accessibilityIdentifier("resumeButton")
                GameButton(title: "Quit run", icon: "xmark", kind: .secondary, height: 52, action: onQuit)
            }
            .padding(.horizontal, 30)
        }
    }
}

struct DeadView: View {
    let skin: Skin
    let canRevive: Bool
    let freeRevive: Bool
    var onRevive: () -> Void
    var onGiveUp: () -> Void
    @State private var count = 9
    /// Set once Revive is tapped, so the countdown can't give up while the rewarded ad is on screen.
    @State private var reviving = false
    var body: some View {
        ZStack {
            Color(red: 0.2, green: 0, blue: 0.05).opacity(0.75).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(skin.texture(.hurt)).resizable().scaledToFit().frame(width: 150)
                Text("NANO IS DOWN!").font(Theme.title(36)).foregroundStyle(.white)
                if canRevive {
                    Text("\(count)").font(Theme.title(56)).foregroundStyle(Theme.gold).contentTransition(.numericText())
                    GameButton(title: freeRevive ? "Revive (free)" : "Revive", icon: freeRevive ? "arrow.counterclockwise" : "play.rectangle.fill",
                               kind: .reward) {
                        guard !reviving else { return }
                        reviving = true
                        onRevive()
                    }
                    .disabled(reviving)
                    .accessibilityIdentifier("reviveButton")
                }
                Button("No thanks") { if !reviving { onGiveUp() } }.font(Theme.body(17)).foregroundStyle(Theme.muted).padding(.top, 4)
                    .accessibilityIdentifier("giveUpButton")
            }
            .padding(.horizontal, 30)
        }
        .task {
            guard canRevive else { return }
            while count > 0 {
                // A cancelled sleep throws: stop here instead of spinning to zero and giving up.
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                if reviving { return }
                withAnimation { count -= 1 }
            }
            if !reviving { onGiveUp() }
        }
    }
}

struct ResultView: View {
    let organ: Organ
    let won: Bool
    @ObservedObject var state: RunState
    let reward: (coins: Int, doubled: Bool)?
    let save: SaveData
    let unlocks: [String]
    var onDouble: () -> Void
    var onDone: () -> Void
    var onNext: () -> Void
    var onVaccine: (Int) -> Void = { _ in }
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            GeometryReader { g in
            ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Image(save.skin.texture(won ? .joy : .hurt)).resizable().scaledToFit().frame(width: unlocks.isEmpty ? 140 : 110)
                    .scaleEffect(appear ? 1 : 0.5).rotationEffect(.degrees(appear ? 0 : -20))
                Text(won ? "\(organ.name.uppercased()) CLEARED!" : organ.isEndless ? "YOU SURVIVED" : "INFECTED!")
                    .font(Theme.title(32)).foregroundStyle(won ? Theme.lime : .white).multilineTextAlignment(.center)
                if !organ.isSideMode {
                    Label("\(save.country.city(organ.infection)), \(save.country.name)", systemImage: "mappin.and.ellipse")
                        .font(Theme.body(14, .bold)).foregroundStyle(Theme.muted)
                }
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
                        GameButton(title: "Double coins", icon: "play.rectangle.fill", kind: .reward, height: 56, action: onDouble)
                            .accessibilityIdentifier("doubleButton")
                    }
                }
                if won && !organ.isSideMode && reward != nil {
                    VaccineLabCard(onDone: onVaccine)
                }
                ForEach(unlocks, id: \.self) { u in
                    Label(u, systemImage: u.contains("cured") ? "cross.case.fill" : u.hasPrefix("Daily") ? "star.fill" : "lock.open.fill").font(Theme.body(16, .heavy)).foregroundStyle(Theme.lime)
                }
                if let r = reward, let g = save.nextGoal {
                    GoalCard(goal: g, coins: save.coins, earned: r.coins)
                }
                if won && !organ.isSideMode, let next = save.nextMission {
                    GameButton(title: "Next: \(next.name) · \(save.country.city(next.infection))", icon: "arrow.right", action: onNext)
                        .accessibilityIdentifier("nextButton")
                }
                GameButton(title: "Continue", kind: .secondary, height: 52, action: onDone)
                    .accessibilityIdentifier("continueButton")
            }
            .padding(.horizontal, 28).padding(.vertical, 20)
            .frame(minHeight: g.size.height)
            }
            }
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

// MARK: - Vaccine Lab

/// After a campaign win: tap MIX while the needle is in the green zone, three tries.
/// Each hit is a star; stars boost the next run.
struct VaccineLabCard: View {
    var onDone: (Int) -> Void
    @State private var start = Date()
    @State private var tries = 0
    @State private var stars = 0
    @State private var flash: Bool?

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image("dr-leuko").resizable().scaledToFit().frame(width: 34, height: 34)
                Text("VACCINE LAB").font(Theme.body(14, .black)).foregroundStyle(Theme.lime)
                Spacer()
                Text(String(repeating: "★", count: stars) + String(repeating: "☆", count: VaccineLab.tries - stars))
                    .font(Theme.body(18, .black)).foregroundStyle(Theme.gold)
            }
            if tries < VaccineLab.tries {
                Text("Tap MIX when the needle is in the green zone. Each hit boosts your next run.")
                    .font(Theme.body(12)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 10) {
                    TimelineView(.animation) { ctx in
                        GeometryReader { g in
                            let z = VaccineLab.zones[tries]
                            let pos = VaccineLab.needle(ctx.date.timeIntervalSince(start))
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.12))
                                Capsule().fill(Theme.lime.opacity(0.7))
                                    .frame(width: g.size.width * z.width)
                                    .offset(x: g.size.width * (z.center - z.width / 2))
                                RoundedRectangle(cornerRadius: 2).fill(.white).frame(width: 4, height: 30)
                                    .offset(x: g.size.width * pos - 2)
                            }
                        }
                    }
                    .frame(height: 26)
                    Button(action: mix) {
                        Text("MIX").font(Theme.body(15, .black)).foregroundStyle(.white)
                            .frame(width: 70, height: 40)
                            .background(RoundedRectangle(cornerRadius: 12).fill(flash == false ? Theme.red : Theme.lime.opacity(0.85)))
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier("mixButton")
                }
            } else {
                Text(stars > 0 ? "Vaccine ready: \(VaccineLab.boostText(stars))" : "The mix failed. Next time!")
                    .font(Theme.body(13, .heavy)).foregroundStyle(stars > 0 ? Theme.lime : Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12).glass(16)
    }

    private func mix() {
        guard tries < VaccineLab.tries else { return }
        let hit = VaccineLab.hit(VaccineLab.needle(Date().timeIntervalSince(start)), try: tries)
        if hit { stars += 1; Sound.coin.play(); Haptics.success() } else { Haptics.error() }
        flash = hit
        tries += 1
        start = Date()
        if tries == VaccineLab.tries { onDone(stars) }
    }
}

// MARK: - First-run helpers

/// Shown at the start of the first run until the player touches the screen.
struct MoveHint: View {
    @State private var swipe = false
    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 44, weight: .bold)).foregroundStyle(.white)
                .shadow(color: Theme.cyan.opacity(0.8), radius: 10)
                .offset(x: swipe ? 50 : -50)
            Text("Drag anywhere to fly").font(Theme.title(26)).foregroundStyle(.white)
            Text("Nano shoots by itself").font(Theme.body(16)).foregroundStyle(Theme.muted)
            Spacer().frame(height: 120)
        }
        .shadow(color: .black.opacity(0.6), radius: 4)
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { swipe = true } }
    }
}

/// "Next: Neon Nano 180 / 250" with a bar that fills from the old balance to the new one.
struct GoalCard: View {
    let goal: (title: String, image: String?, symbol: String?, cost: Int)
    let coins: Int
    let earned: Int
    @State private var fill: Double = 0

    var body: some View {
        let ready = coins >= goal.cost
        HStack(spacing: 12) {
            Group {
                if let img = goal.image { Image(img).resizable().scaledToFit() }
                else if let sym = goal.symbol { Image(systemName: sym).font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.cyan) }
            }
            .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 5) {
                Text(ready ? "READY TO UNLOCK" : "NEXT UNLOCK").font(Theme.body(11, .black)).foregroundStyle(ready ? Theme.lime : Theme.cyan).tracking(1.5)
                Text(goal.title).font(Theme.body(16, .heavy)).foregroundStyle(.white)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.black.opacity(0.45))
                        Capsule().fill(LinearGradient(kind: .reward, startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(8, g.size.width * fill))
                    }
                }
                .frame(height: 9)
            }
            HStack(spacing: 3) {
                Image("coin").resizable().frame(width: 16, height: 16)
                Text("\(min(coins, goal.cost))/\(goal.cost)").font(Theme.body(13, .heavy)).foregroundStyle(.white).monospacedDigit()
            }
        }
        .padding(12).glass(16)
        .onAppear {
            let start = Double(max(0, coins - earned)) / Double(max(1, goal.cost))
            fill = min(1, start)
            withAnimation(.easeOut(duration: 1.2).delay(0.5)) { fill = min(1, Double(coins) / Double(max(1, goal.cost))) }
        }
    }
}
