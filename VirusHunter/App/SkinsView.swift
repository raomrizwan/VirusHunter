import SwiftUI

/// Pick Nano's look. Locked skins show their price or how to earn them.
struct SkinsView: View {
    @EnvironmentObject var model: AppModel
    @State private var selected: Skin = .classic
    @State private var float = false

    var body: some View {
        ZStack {
            MenuBackground(tint: Theme.magenta)
            VStack(spacing: 12) {
                HStack {
                    Button { model.go(.home) } label: {
                        Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy)).foregroundStyle(.white).frame(width: 44, height: 44).glass(14)
                    }
                    .accessibilityIdentifier("backButton")
                    Spacer()
                    Text("SKINS").font(Theme.title(24)).foregroundStyle(.white)
                    Spacer()
                    CoinBadge(coins: model.save.coins)
                }
                .padding(.horizontal, 20).padding(.top, 6)

                ZStack {
                    Circle().fill(RadialGradient(colors: [Theme.cyan.opacity(0.3), .clear], center: .center, startRadius: 10, endRadius: 140)).frame(width: 280, height: 280)
                    Image(selected.texture(.happy)).resizable().scaledToFit().frame(width: 180)
                        .offset(y: float ? -8 : 6)
                        .id(selected).transition(.scale.combined(with: .opacity))
                }
                .frame(height: 220)
                .onAppear { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { float = true } }

                Text(selected.title).font(Theme.title(28)).foregroundStyle(.white)
                action.padding(.horizontal, 28)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Skin.allCases) { cell($0) }
                    }
                    .padding(.horizontal, 18).padding(.bottom, 30)
                }
            }
        }
        .onAppear { selected = model.save.skin }
    }

    @ViewBuilder private var action: some View {
        let s = model.save
        if s.skin == selected {
            GameButton(title: "Equipped", icon: "checkmark", colors: [Color(white: 0.45), Color(white: 0.25)], height: 56) {}
        } else if s.owns(selected) {
            GameButton(title: "Equip", icon: "tshirt.fill", height: 56) { model.save.equip(selected); model.persist() }
                .accessibilityIdentifier("equipSkin")
        } else if let p = selected.price {
            let afford = s.coins >= p
            GameButton(title: "Buy \(p)", icon: "bitcoinsign.circle.fill",
                       colors: afford ? [Theme.gold, Color(red: 0.95, green: 0.5, blue: 0.1)] : [Color(white: 0.45), Color(white: 0.25)], height: 56) {
                if model.save.buy(selected) {
                    model.save.equip(selected); model.persist(); Sound.levelup.play(); Haptics.success()
                } else { Haptics.error() }
            }
            .accessibilityIdentifier("buySkin")
        } else {
            Text(selected.howToGet).font(Theme.body(17, .heavy)).foregroundStyle(Theme.gold)
                .frame(maxWidth: .infinity, minHeight: 56).glass(18)
        }
    }

    private func cell(_ k: Skin) -> some View {
        let owned = model.save.owns(k)
        let isSel = k == selected
        return Button {
            withAnimation(.spring(duration: 0.35)) { selected = k }
            Sound.tap.play(); Haptics.light()
        } label: {
            VStack(spacing: 6) {
                Image(k.texture(.happy)).resizable().scaledToFit().frame(height: 64)
                    .saturation(owned ? 1 : 0.2).opacity(owned ? 1 : 0.7)
                if model.save.skin == k {
                    Text("ON").font(Theme.body(12, .black)).foregroundStyle(Theme.lime)
                } else if owned {
                    Text("Owned").font(Theme.body(12, .heavy)).foregroundStyle(Theme.muted)
                } else if let p = k.price {
                    HStack(spacing: 3) { Image("coin").resizable().frame(width: 13, height: 13); Text("\(p)").font(Theme.body(12, .heavy)).foregroundStyle(.white) }
                } else {
                    Image(systemName: "lock.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.gold)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .glass(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSel ? Theme.cyan : .clear, lineWidth: 2.5))
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier("skin-\(k.rawValue)")
    }
}
