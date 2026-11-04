import SwiftUI

struct MapView: View {
    @EnvironmentObject var model: AppModel
    @State private var selected: Int = 1
    @State private var infection: [Int: Int] = [:]   // chosen Infection Level per organ
    @State private var pulse = false

    // Organ positions on the body art (fractions of the image).
    private let spots: [Int: CGPoint] = [1: CGPoint(x: 0.42, y: 0.32), 2: CGPoint(x: 0.58, y: 0.37), 3: CGPoint(x: 0.48, y: 0.48),
                                         4: CGPoint(x: 0.5, y: 0.12), 5: CGPoint(x: 0.41, y: 0.76)]

    var body: some View {
        ZStack {
            MenuBackground()
            VStack(spacing: 10) {
                HStack {
                    Button { model.go(.home) } label: {
                        Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy)).foregroundStyle(.white).frame(width: 44, height: 44).glass(14)
                    }
                    .accessibilityIdentifier("backButton")
                    Spacer()
                    Text("BODY MAP").font(Theme.title(24)).foregroundStyle(.white)
                    Spacer()
                    CoinBadge(coins: model.save.coins)
                }
                .padding(.horizontal, 20).padding(.top, 6)

                GeometryReader { geo in
                    let h = geo.size.height, w = h * 0.6
                    ZStack {
                        Image("bodymap").resizable().frame(width: w, height: h)
                        ForEach(Organ.all) { o in
                            let p = spots[o.id]!
                            organDot(o).position(x: (geo.size.width - w) / 2 + p.x * w, y: p.y * h)
                        }
                    }
                    .frame(width: geo.size.width, height: h)
                }
                .padding(.vertical, 4)

                card(Organ.all[selected - 1]).padding(.horizontal, 20).padding(.bottom, 16)
            }
        }
        .onAppear {
            selected = min(model.save.unlockedStage, 5)
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func organDot(_ o: Organ) -> some View {
        let unlocked = o.id <= model.save.unlockedStage
        let cleared = model.save.clearedStages.contains(o.id)
        let isSel = o.id == selected
        let color: Color = cleared ? Theme.lime : unlocked ? Theme.magenta : .gray
        return Button {
            if unlocked { selected = o.id; Sound.tap.play(); Haptics.light() }
        } label: {
            ZStack {
                if unlocked && !cleared {
                    Circle().stroke(color, lineWidth: 3).frame(width: 64, height: 64).scaleEffect(pulse ? 1.25 : 0.9).opacity(pulse ? 0 : 0.9)
                }
                Circle().fill(color.opacity(0.25)).frame(width: isSel ? 62 : 50, height: isSel ? 62 : 50)
                Circle().stroke(color, lineWidth: isSel ? 4 : 2).frame(width: isSel ? 62 : 50, height: isSel ? 62 : 50)
                if cleared && model.save.clearedInfection(o.id) > 1 {
                    Text("\(model.save.clearedInfection(o.id))").font(Theme.title(22)).foregroundStyle(.white)
                } else if cleared { Image(systemName: "checkmark").font(.system(size: 20, weight: .black)).foregroundStyle(.white) }
                else if unlocked { Image("virus-\(["spiky", "mini", "spitter", "blob", "dart"][o.id - 1])").resizable().frame(width: 40, height: 40) }
                else { Image(systemName: "lock.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(.white.opacity(0.7)) }
            }
            .shadow(color: color.opacity(0.8), radius: isSel ? 14 : 6)
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier("organ\(o.id)")
    }

    private func level(for o: Organ) -> Int {
        let top = model.save.unlockedInfection(o.id)
        return min(top, infection[o.id] ?? top)
    }

    private func card(_ base: Organ) -> some View {
        let o = base.at(infection: level(for: base))
        return VStack(spacing: 12) {
            HStack(spacing: 14) {
                Image(o.boss.texture).resizable().frame(width: 84, height: 84).shadow(color: Theme.magenta.opacity(0.5), radius: 10)
                VStack(alignment: .leading, spacing: 4) {
                    Text("STAGE \(o.id)").font(Theme.body(12, .heavy)).foregroundStyle(Theme.cyan).tracking(2)
                    Text(o.name).font(Theme.title(26)).foregroundStyle(.white)
                    Text("Boss: \(o.boss.bossTitle)").font(Theme.body(14)).foregroundStyle(Theme.muted)
                    if model.save.clearedStages.contains(o.id) {
                        let best = model.save.clearedInfection(o.id)
                        Label(best > 1 ? "Cleared up to Level \(best)" : "Cleared", systemImage: "checkmark.seal.fill")
                            .font(Theme.body(13, .bold)).foregroundStyle(Theme.lime)
                    }
                }
                Spacer(minLength: 0)
                Button {
                    Sound.tap.play(); Haptics.medium(); model.go(.game(o))
                } label: {
                    Image(systemName: "play.fill").font(.system(size: 26, weight: .black)).foregroundStyle(.white)
                        .frame(width: 66, height: 66)
                        .background(Circle().fill(LinearGradient(colors: [Color(red: 0.35, green: 1, blue: 0.6), Color(red: 0.05, green: 0.7, blue: 0.45)], startPoint: .top, endPoint: .bottom)))
                        .shadow(color: Theme.lime.opacity(0.6), radius: 10)
                }
                .buttonStyle(PressStyle())
                .accessibilityIdentifier("startStage")
            }
            if model.save.clearedStages.contains(o.id) { infectionPicker(o) }
        }
        .padding(16)
        .glass()
    }

    /// Infection Level stepper, shown once an organ is cleared.
    private func infectionPicker(_ o: Organ) -> some View {
        let top = model.save.unlockedInfection(o.id)
        let lv = o.infection
        return HStack(spacing: 12) {
            stepButton("minus", enabled: lv > 1) { infection[o.id] = lv - 1 }
            VStack(spacing: 2) {
                Text("INFECTION LEVEL \(lv)").font(Theme.body(13, .heavy)).foregroundStyle(lv > 1 ? Theme.magenta : Theme.cyan).tracking(1.5)
                Text(lv == 1 ? "Normal viruses" : "Viruses +\(Int((o.difficulty / o.at(infection: 1).difficulty - 1) * 100))% stronger · \(String(format: "%.1f", Double(o.coinReward) / Double(o.at(infection: 1).coinReward)))x coins")
                    .font(Theme.body(12, .medium)).foregroundStyle(Theme.muted)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            stepButton("plus", enabled: lv < top) { infection[o.id] = lv + 1 }
        }
        .accessibilityIdentifier("infectionPicker")
    }

    private func stepButton(_ icon: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button { action(); Sound.tap.play(); Haptics.light() } label: {
            Image(systemName: icon).font(.system(size: 16, weight: .black)).foregroundStyle(.white.opacity(enabled ? 1 : 0.3))
                .frame(width: 40, height: 36).background(RoundedRectangle(cornerRadius: 11).fill(.white.opacity(enabled ? 0.15 : 0.05)))
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
    }
}

struct LabView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            MenuBackground(tint: Color(red: 0.6, green: 0.4, blue: 1))
            VStack(spacing: 12) {
                HStack {
                    Button { model.go(.home) } label: {
                        Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy)).foregroundStyle(.white).frame(width: 44, height: 44).glass(14)
                    }
                    .accessibilityIdentifier("backButton")
                    Spacer()
                    Text("TECH LAB").font(Theme.title(24)).foregroundStyle(.white)
                    Spacer()
                    CoinBadge(coins: model.save.coins)
                }
                .padding(.horizontal, 20).padding(.top, 6)
                Text("Permanent upgrades for Nano. After MAX, keep going with Mutation Ranks.")
                    .font(Theme.body(14, .medium)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).padding(.horizontal, 30)
                ScrollView {
                    VStack(spacing: 10) { ForEach(TechKind.allCases) { row($0) } }.padding(.horizontal, 18).padding(.bottom, 30)
                }
            }
        }
    }

    private func row(_ t: TechKind) -> some View {
        let l = model.save.level(t)
        let r = model.save.rank(t)
        let next = model.save.nextCost(t)
        let maxed = next == nil
        let ranking = l >= t.maxLevel && !maxed   // buying Mutation Ranks now
        let cost = next ?? 0
        let afford = model.save.coins >= cost
        return HStack(spacing: 14) {
            Image(systemName: t.symbol).font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.cyan)
                .frame(width: 52, height: 52).background(RoundedRectangle(cornerRadius: 14).fill(Theme.cyan.opacity(0.15)))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(t.title).font(Theme.body(17, .heavy)).foregroundStyle(.white)
                    if r > 0 {
                        Text("RANK \(r)").font(Theme.body(10, .black)).foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(Theme.magenta))
                    }
                }
                Text(t.effect(max(l, 1), rank: r)).font(Theme.body(13)).foregroundStyle(Theme.muted)
                if l >= t.maxLevel && t.maxRank > 0 {
                    Text(maxed ? "All Mutation Ranks done" : "Next rank: \(t.effect(l, rank: r + 1))")
                        .font(Theme.body(11, .bold)).foregroundStyle(Theme.magenta)
                } else {
                    HStack(spacing: 3) {
                        ForEach(0..<t.maxLevel, id: \.self) { i in
                            Capsule().fill(i < l ? Theme.cyan : .white.opacity(0.15)).frame(height: 5)
                        }
                    }
                    .frame(maxWidth: 150)
                }
            }
            Spacer(minLength: 0)
            Button {
                if model.save.buy(t) { model.persist(); Sound.levelup.play(); Haptics.success() } else { Haptics.error() }
            } label: {
                Group {
                    if maxed { Text("MAX").font(Theme.body(15, .heavy)) }
                    else { HStack(spacing: 4) { Image("coin").resizable().frame(width: 18, height: 18); Text("\(cost)").font(Theme.body(15, .heavy)).monospacedDigit() } }
                }
                .foregroundStyle(.white)
                .frame(width: 92, height: 42)
                .background(RoundedRectangle(cornerRadius: 13).fill(maxed ? Color.gray.opacity(0.4) : !afford ? Color.white.opacity(0.12) : ranking ? Theme.magenta.opacity(0.85) : Color(red: 0.1, green: 0.75, blue: 0.5)))
            }
            .disabled(maxed)
            .buttonStyle(PressStyle())
        }
        .padding(14)
        .glass(18)
    }
}
