import SwiftUI

/// Dr. Leuko's white blood cell allies: recruit with coins (the Medic joins after the first city)
/// and pick one to fly with Nano.
struct AlliesView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            MenuBackground(tint: Theme.lime)
            VStack(spacing: 12) {
                HStack {
                    Button { model.go(.home) } label: {
                        Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy)).foregroundStyle(.white).frame(width: 44, height: 44).glass(14)
                    }
                    .accessibilityIdentifier("backButton")
                    Spacer()
                    Text("ALLIES & PETS").font(Theme.title(22)).foregroundStyle(.white)
                    Spacer()
                    CoinBadge(coins: model.save.coins)
                }
                .padding(.horizontal, 20).padding(.top, 6)

                HStack(spacing: 12) {
                    Image("dr-leuko").resizable().scaledToFit().frame(width: 70, height: 70)
                    Text("\"My best white blood cells will fly with you. Pick one, Nano!\"")
                        .font(Theme.body(14, .semibold)).foregroundStyle(.white)
                }
                .padding(12).glass(16).padding(.horizontal, 20)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Ally.allCases) { row($0) }
                        Text("PETS").font(Theme.body(13, .black)).foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                        Text("Your pet flies with Nano in every run and levels up as you play.")
                            .font(Theme.body(12)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(Pet.allCases) { petRow($0) }
                    }
                    .padding(.horizontal, 18).padding(.bottom, 30)
                }
            }
        }
    }

    private func petRow(_ p: Pet) -> some View {
        let s = model.save
        let owned = s.ownsPet(p)
        let active = s.pet == p
        let l = s.petLevel(p)
        let xp = s.petXP[p.rawValue] ?? 0
        let lo = Pet.thresholds[l - 1]
        let hi = l < Pet.maxLevel ? Pet.thresholds[l] : lo
        return HStack(spacing: 14) {
            Image(p.texture).resizable().scaledToFit().frame(width: 70, height: 70)
                .opacity(owned ? 1 : 0.55)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(p.title).font(Theme.body(16, .heavy)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                    Text("LV \(l)").font(Theme.body(10, .black)).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(Theme.magenta))
                }
                Text(p.detail).font(Theme.body(12)).foregroundStyle(Theme.muted)
                Text(p.effect(l)).font(Theme.body(11, .bold)).foregroundStyle(Theme.lime)
                if owned {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.12))
                            Capsule().fill(Theme.lime)
                                .frame(width: hi > lo ? g.size.width * Double(xp - lo) / Double(hi - lo) : g.size.width)
                        }
                    }
                    .frame(width: 130, height: 5)
                }
            }
            Spacer(minLength: 0)
            Button {
                var ns = model.save
                guard ns.adoptPet(p) else { Haptics.error(); return }
                Sound.coin.play(); Haptics.success()
                model.save = ns; model.persist()
            } label: {
                Group {
                    if active { Text("With Nano") }
                    else if owned { Text("Pick") }
                    else { HStack(spacing: 4) { Image("coin").resizable().frame(width: 16, height: 16); Text(p.price.formatted()) } }
                }
                .font(Theme.body(13, .heavy)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 12).frame(height: 38)
                .background(Capsule().fill(active ? Theme.lime.opacity(0.35) : owned ? Theme.cyan.opacity(0.35) : .white.opacity(0.12)))
            }
            .buttonStyle(PressStyle())
            .disabled(active)
            .accessibilityIdentifier("pet-\(p.rawValue)")
        }
        .padding(14).glass(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(active ? Theme.lime : .clear, lineWidth: 2))
    }

    private func row(_ a: Ally) -> some View {
        let s = model.save
        let owned = s.ownsAlly(a)
        let active = s.ally == a
        return HStack(spacing: 14) {
            Image(a.texture).resizable().scaledToFit().frame(width: 76, height: 76)
                .opacity(owned ? 1 : 0.55)
            VStack(alignment: .leading, spacing: 5) {
                Text(a.title).font(Theme.body(17, .heavy)).foregroundStyle(.white)
                Text(a.detail).font(Theme.body(12)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            Button {
                var ns = model.save
                if active { ns.allyID = nil }
                else if !ns.recruitAlly(a) { Haptics.error(); return }
                Sound.coin.play(); Haptics.success()
                model.save = ns; model.persist()
            } label: {
                Group {
                    if active { Text("With Nano") }
                    else if owned { Text("Pick") }
                    else if a == .medic { Text("Save a city") }
                    else { HStack(spacing: 4) { Image("coin").resizable().frame(width: 16, height: 16); Text(a.price.formatted()) } }
                }
                .font(Theme.body(13, .heavy)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 12).frame(height: 38)
                .background(Capsule().fill(active ? Theme.lime.opacity(0.35) : owned ? Theme.cyan.opacity(0.35) : .white.opacity(0.12)))
            }
            .buttonStyle(PressStyle())
            .disabled(!owned && a == .medic)
            .accessibilityIdentifier("ally-\(a.rawValue)")
        }
        .padding(14).glass(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(active ? Theme.lime : .clear, lineWidth: 2))
    }
}
