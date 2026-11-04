import SwiftUI

/// Daily missions, the all-done bonus and the login streak.
struct DailyView: View {
    @EnvironmentObject var model: AppModel
    @State private var flash: String?

    private var daily: DailyState { model.save.daily }

    var body: some View {
        ZStack {
            MenuBackground(tint: Theme.gold)
            VStack(spacing: 12) {
                HStack {
                    Button { model.go(.home) } label: {
                        Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy)).foregroundStyle(.white).frame(width: 44, height: 44).glass(14)
                    }
                    .accessibilityIdentifier("backButton")
                    Spacer()
                    Text("DAILY").font(Theme.title(24)).foregroundStyle(.white)
                    Spacer()
                    CoinBadge(coins: model.save.coins)
                }
                .padding(.horizontal, 20).padding(.top, 6)

                ScrollView {
                    VStack(spacing: 12) {
                        streakCard
                        Text("TODAY'S MISSIONS").font(Theme.body(13, .heavy)).tracking(2).foregroundStyle(Theme.cyan)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                        ForEach(daily.missions) { missionRow($0) }
                        bonusCard
                        Text("New missions every day at midnight.").font(Theme.body(12)).foregroundStyle(Theme.muted)
                    }
                    .padding(.horizontal, 18).padding(.bottom, 30)
                }
            }
            if let f = flash {
                Text(f).font(Theme.title(34)).foregroundStyle(Theme.gold).shadow(color: Theme.gold.opacity(0.7), radius: 12)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .onAppear { model.refreshDaily() }
    }

    // MARK: streak

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("LOGIN STREAK", systemImage: "flame.fill").font(Theme.body(13, .heavy)).tracking(1.5).foregroundStyle(Theme.red)
                Spacer()
                Text(daily.streak == 1 ? "1 day" : "\(daily.streak) days").font(Theme.body(14, .heavy)).foregroundStyle(.white)
            }
            HStack(spacing: 6) {
                ForEach(0..<DailyState.streakRewards.count, id: \.self) { i in
                    let day = i + 1
                    let current = min(daily.streak, DailyState.streakRewards.count)
                    let reached = day <= current
                    VStack(spacing: 4) {
                        Text("Day \(day)").font(Theme.body(10, .heavy)).foregroundStyle(.white.opacity(0.7))
                        Image("coin").resizable().frame(width: day == 7 ? 26 : 18, height: day == 7 ? 26 : 18)
                        Text("\(DailyState.streakRewards[i])").font(Theme.body(11, .heavy)).foregroundStyle(reached ? Theme.gold : .white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(day == current ? Theme.gold.opacity(0.25) : .white.opacity(reached ? 0.1 : 0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(day == current ? Theme.gold : .clear, lineWidth: 2))
                }
            }
            if daily.canClaimStreak {
                GameButton(title: "Claim \(daily.streakReward) coins", icon: "gift.fill", kind: .reward, height: 52) {
                    claim { $0.claimStreak() }
                }
                .accessibilityIdentifier("claimStreak")
            } else {
                Text("Come back tomorrow to keep your streak.").font(Theme.body(13)).foregroundStyle(Theme.muted)
            }
        }
        .padding(16).glass(20)
    }

    // MARK: missions

    private func missionRow(_ m: Mission) -> some View {
        HStack(spacing: 14) {
            Image(systemName: m.kind.symbol).font(.system(size: 22, weight: .bold)).foregroundStyle(m.done ? Theme.lime : Theme.cyan)
                .frame(width: 48, height: 48).background(RoundedRectangle(cornerRadius: 14).fill((m.done ? Theme.lime : Theme.cyan).opacity(0.15)))
            VStack(alignment: .leading, spacing: 6) {
                Text(m.title).font(Theme.body(15, .heavy)).foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.8)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule().fill(m.done ? Theme.lime : Theme.cyan).frame(width: max(6, g.size.width * m.fraction))
                    }
                }
                .frame(height: 6)
                Text(progressText(m)).font(Theme.body(11, .bold)).foregroundStyle(Theme.muted).monospacedDigit()
            }
            Spacer(minLength: 0)
            Button {
                claim { $0.claimMission(m.id) }
            } label: {
                Group {
                    if m.claimed { Image(systemName: "checkmark").font(.system(size: 16, weight: .black)) }
                    else { HStack(spacing: 3) { Image("coin").resizable().frame(width: 16, height: 16); Text("\(m.reward)").font(Theme.body(14, .heavy)) } }
                }
                .foregroundStyle(.white)
                .frame(width: 78, height: 40)
                .background(RoundedRectangle(cornerRadius: 12).fill(m.claimed ? Color.gray.opacity(0.4) : m.done ? Color(red: 0.2, green: 0.6, blue: 1) : .white.opacity(0.12)))
            }
            .buttonStyle(PressStyle())
            .disabled(!m.done || m.claimed)
            .accessibilityIdentifier("claimMission\(m.id)")
        }
        .padding(14).glass(18)
    }

    private func progressText(_ m: Mission) -> String {
        switch m.kind {
        case .survive, .endless: return "\(timeString(Double(min(m.progress, m.target)))) / \(timeString(Double(m.target)))"
        default: return "\(min(m.progress, m.target).formatted()) / \(m.target.formatted())"
        }
    }

    private var bonusCard: some View {
        HStack(spacing: 14) {
            Image("chest").resizable().scaledToFit().frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text("All 3 missions").font(Theme.body(15, .heavy)).foregroundStyle(.white)
                Text(daily.bonusClaimed ? "Bonus collected" : "Bonus chest: \(DailyState.bonusReward) coins").font(Theme.body(13)).foregroundStyle(Theme.muted)
            }
            Spacer()
            if daily.canClaimBonus {
                Button { claim { $0.claimDailyBonus() } } label: {
                    Text("Open").font(Theme.body(15, .heavy)).foregroundStyle(.white).frame(width: 78, height: 40)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.gold))
                }
                .buttonStyle(PressStyle())
                .accessibilityIdentifier("claimBonus")
            }
        }
        .padding(14).glass(18)
    }

    private func claim(_ action: (inout SaveData) -> Int?) {
        var s = model.save
        guard let coins = action(&s) else { Haptics.error(); return }
        model.save = s
        model.persist()
        GameCenter.sync(s)
        Sound.coin.play(); Haptics.success()
        withAnimation(.spring(duration: 0.4, bounce: 0.5)) { flash = "+\(coins)" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { withAnimation { flash = nil } }
    }
}
