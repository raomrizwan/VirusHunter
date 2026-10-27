import SwiftUI

struct MapView: View {
    @EnvironmentObject var model: AppModel
    @State private var selected: Int = 1
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
                if cleared { Image(systemName: "checkmark").font(.system(size: 20, weight: .black)).foregroundStyle(.white) }
                else if unlocked { Image("virus-\(["spiky", "mini", "spitter", "blob", "dart"][o.id - 1])").resizable().frame(width: 40, height: 40) }
                else { Image(systemName: "lock.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(.white.opacity(0.7)) }
            }
            .shadow(color: color.opacity(0.8), radius: isSel ? 14 : 6)
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier("organ\(o.id)")
    }

    private func card(_ o: Organ) -> some View {
        HStack(spacing: 14) {
            Image(o.boss.texture).resizable().frame(width: 84, height: 84).shadow(color: Theme.magenta.opacity(0.5), radius: 10)
            VStack(alignment: .leading, spacing: 4) {
                Text("STAGE \(o.id)").font(Theme.body(12, .heavy)).foregroundStyle(Theme.cyan).tracking(2)
                Text(o.name).font(Theme.title(26)).foregroundStyle(.white)
                Text("Boss: \(o.boss.bossTitle)").font(Theme.body(14)).foregroundStyle(Theme.muted)
                if model.save.clearedStages.contains(o.id) {
                    Label("Cleared", systemImage: "checkmark.seal.fill").font(Theme.body(13, .bold)).foregroundStyle(Theme.lime)
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
        .padding(16)
        .glass()
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
                Text("Permanent upgrades for Nano. Earn Bio-Coins in every run.")
                    .font(Theme.body(14, .medium)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).padding(.horizontal, 30)
                ScrollView {
                    VStack(spacing: 10) { ForEach(TechKind.allCases) { row($0) } }.padding(.horizontal, 18).padding(.bottom, 30)
                }
            }
        }
    }

    private func row(_ t: TechKind) -> some View {
        let l = model.save.level(t)
        let maxed = l >= t.maxLevel
        let cost = maxed ? 0 : t.cost(toLevel: l + 1)
        let afford = model.save.coins >= cost
        return HStack(spacing: 14) {
            Image(systemName: t.symbol).font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.cyan)
                .frame(width: 52, height: 52).background(RoundedRectangle(cornerRadius: 14).fill(Theme.cyan.opacity(0.15)))
            VStack(alignment: .leading, spacing: 4) {
                Text(t.title).font(Theme.body(17, .heavy)).foregroundStyle(.white)
                Text(t.effect(max(l, 1))).font(Theme.body(13)).foregroundStyle(Theme.muted)
                HStack(spacing: 3) {
                    ForEach(0..<t.maxLevel, id: \.self) { i in
                        Capsule().fill(i < l ? Theme.cyan : .white.opacity(0.15)).frame(height: 5)
                    }
                }
                .frame(maxWidth: 150)
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
                .background(RoundedRectangle(cornerRadius: 13).fill(maxed ? Color.gray.opacity(0.4) : afford ? Color(red: 0.1, green: 0.75, blue: 0.5) : Color.white.opacity(0.12)))
            }
            .disabled(maxed)
            .buttonStyle(PressStyle())
        }
        .padding(14)
        .glass(18)
    }
}
