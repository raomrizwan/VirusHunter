import SwiftUI

/// Free monthly Season Pass: 30 tiers earned with season XP from every run.
struct SeasonView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let s = model.save
        ZStack {
            MenuBackground(tint: Theme.gold)
            VStack(spacing: 12) {
                HStack {
                    Button { model.go(.home) } label: {
                        Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy)).foregroundStyle(.white).frame(width: 44, height: 44).glass(14)
                    }
                    .accessibilityIdentifier("backButton")
                    Spacer()
                    Text("SEASON PASS").font(Theme.title(24)).foregroundStyle(.white)
                    Spacer()
                    CoinBadge(coins: s.coins)
                }
                .padding(.horizontal, 20).padding(.top, 6)

                VStack(spacing: 8) {
                    HStack {
                        Text(Season.title(s.seasonKey).uppercased()).font(Theme.body(15, .black)).foregroundStyle(Theme.gold)
                        Spacer()
                        Text("Tier \(s.seasonTier)/\(Season.tiers)").font(Theme.body(15, .heavy)).foregroundStyle(.white)
                    }
                    let into = s.seasonTier >= Season.tiers ? Season.xpPerTier : s.seasonXP % Season.xpPerTier
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.12))
                            Capsule().fill(LinearGradient(colors: [Theme.gold, Color(red: 1, green: 0.55, blue: 0.2)], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(8, g.size.width * Double(into) / Double(Season.xpPerTier)))
                        }
                    }
                    .frame(height: 10)
                    Text("Every run earns season XP. Bosses, long runs and wins earn more. A new season starts every month.")
                        .font(Theme.body(12)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity, alignment: .leading)
                    if s.unclaimedSeasonTiers > 0 {
                        GameButton(title: "Claim \(s.unclaimedSeasonTiers) reward\(s.unclaimedSeasonTiers == 1 ? "" : "s")", icon: "gift.fill",
                                   colors: [Theme.gold, Color(red: 0.95, green: 0.5, blue: 0.1)], height: 52) {
                            var ns = model.save
                            _ = ns.claimSeason()
                            model.save = ns; model.persist()
                            Sound.levelup.play(); Haptics.success()
                        }
                        .accessibilityIdentifier("claimSeason")
                    }
                }
                .padding(14).glass(18).padding(.horizontal, 18)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(1...Season.tiers, id: \.self) { row($0, s) }
                    }
                    .padding(.horizontal, 18).padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            var ns = model.save
            ns.refreshSeason()
            if ns.seasonKey != model.save.seasonKey { model.save = ns; model.persist() }
        }
    }

    private func row(_ tier: Int, _ s: SaveData) -> some View {
        let reward = Season.reward(tier: tier)
        let claimed = tier <= s.seasonClaimed
        let reached = tier <= s.seasonTier
        let isDNA: Bool = { if case .dna = reward { return true } else { return false } }()
        return HStack(spacing: 12) {
            Text("\(tier)").font(Theme.title(20)).foregroundStyle(reached ? Theme.gold : Theme.muted).frame(width: 40)
            Group {
                if isDNA { Text("🧬").font(.system(size: 22)) } else { Image("coin").resizable().frame(width: 24, height: 24) }
            }
            .frame(width: 30)
            Text(reward.title).font(Theme.body(15, .heavy)).foregroundStyle(.white)
            Spacer()
            Image(systemName: claimed ? "checkmark.circle.fill" : reached ? "gift.fill" : "lock.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(claimed ? Theme.lime : reached ? Theme.gold : Theme.muted)
        }
        .padding(.horizontal, 14).frame(height: 50).glass(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tier % 5 == 0 ? Theme.lime.opacity(0.4) : .clear, lineWidth: 1.5))
    }
}
