import SwiftUI

/// In-game achievements: opens instantly, shows progress and pays coins.
/// Game Center leaderboards are one button away, shown only when the player is signed in.
struct TrophiesView: View {
    @EnvironmentObject var model: AppModel
    @State private var flash: String?

    var body: some View {
        let s = model.save
        let done = Trophy.allCases.filter { $0.done(s) }.count
        ZStack {
            MenuBackground(tint: Theme.gold)
            VStack(spacing: 12) {
                HStack {
                    Button { model.go(.home) } label: {
                        Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy)).foregroundStyle(.white).frame(width: 44, height: 44).glass(14)
                    }
                    .accessibilityIdentifier("backButton")
                    Spacer()
                    Text("TROPHIES").font(Theme.title(24)).foregroundStyle(.white)
                    Spacer()
                    CoinBadge(coins: s.coins)
                }
                .padding(.horizontal, 20).padding(.top, 6)

                HStack {
                    Label("\(done) / \(Trophy.allCases.count) unlocked", systemImage: "trophy.fill")
                        .font(Theme.body(15, .heavy)).foregroundStyle(Theme.gold)
                    Spacer()
                    if GameCenter.enabled {
                        Button { GameCenter.showDashboard() } label: {
                            Label("Leaderboards", systemImage: "list.number").font(Theme.body(13, .heavy)).foregroundStyle(.white)
                                .padding(.horizontal, 12).padding(.vertical, 8).glass(12)
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityIdentifier("leaderboardsButton")
                    }
                }
                .padding(.horizontal, 20)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(Trophy.allCases) { row($0, s) }
                    }
                    .padding(.horizontal, 18).padding(.bottom, 30)
                }
            }
            if let f = flash {
                Text(f).font(Theme.title(34)).foregroundStyle(Theme.gold).shadow(color: Theme.gold.opacity(0.7), radius: 12)
                    .transition(.scale.combined(with: .opacity)).allowsHitTesting(false)
            }
        }
    }

    private func row(_ t: Trophy, _ s: SaveData) -> some View {
        let (cur, target) = t.progress(s)
        let done = cur >= target
        let claimed = s.claimedTrophies.contains(t.rawValue)
        return HStack(spacing: 14) {
            Image(systemName: t.symbol).font(.system(size: 22, weight: .bold)).foregroundStyle(done ? Theme.gold : .white.opacity(0.45))
                .frame(width: 50, height: 50).background(Circle().fill((done ? Theme.gold : Color.white).opacity(done ? 0.2 : 0.06)))
            VStack(alignment: .leading, spacing: 5) {
                Text(t.title).font(Theme.body(16, .heavy)).foregroundStyle(.white)
                Text(t.detail).font(Theme.body(12)).foregroundStyle(Theme.muted)
                if !done {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.12))
                            Capsule().fill(Theme.cyan).frame(width: max(5, g.size.width * min(1, Double(cur) / Double(target))))
                        }
                    }
                    .frame(height: 5)
                    Text("\(min(cur, target).formatted()) / \(target.formatted())").font(Theme.body(11, .bold)).foregroundStyle(Theme.muted).monospacedDigit()
                }
            }
            Spacer(minLength: 0)
            Button {
                var ns = model.save
                guard let c = ns.claimTrophy(t) else { Haptics.error(); return }
                model.save = ns; model.persist()
                Sound.coin.play(); Haptics.success()
                withAnimation(.spring(duration: 0.4, bounce: 0.5)) { flash = "+\(c)" }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { withAnimation { flash = nil } }
            } label: {
                Group {
                    if claimed { Image(systemName: "checkmark").font(.system(size: 16, weight: .black)) }
                    else { HStack(spacing: 3) { Image("coin").resizable().frame(width: 16, height: 16); Text("\(t.reward.formatted())").font(Theme.body(13, .heavy)) } }
                }
                .foregroundStyle(.white).frame(width: 82, height: 40)
                .background(RoundedRectangle(cornerRadius: 12).fill(claimed ? Color.gray.opacity(0.4) : done ? Color(red: 0.2, green: 0.6, blue: 1) : .white.opacity(0.1)))
            }
            .buttonStyle(PressStyle())
            .disabled(!done || claimed)
            .accessibilityIdentifier("trophy-\(t.rawValue)")
        }
        .padding(14).glass(18)
    }
}
