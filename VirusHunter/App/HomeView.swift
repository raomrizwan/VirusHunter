import SwiftUI

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("sound") private var sound = true
    @AppStorage("haptics") private var haptics = true
    @State private var float = false
    @State private var spin = false
    @State private var pulse = false

    var body: some View {
        let s = model.save
        ZStack {
            MenuBackground(tint: Theme.cyan, image: s.countryCode == nil ? "bg-endless" : Organ.all[(max(1, s.currentCity) - 1) % 5].backdrop)
            FloatingViruses()
            VStack(spacing: 0) {
                topBar(s)
                    .padding(.horizontal, 20).padding(.top, 8)

                VStack(spacing: 0) {
                    Text("VIRUS HUNTER")
                        .font(Theme.title(38))
                        .foregroundStyle(LinearGradient(colors: [.white, Theme.cyan], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Theme.cyan.opacity(0.7), radius: 14)
                    Text("NANO WAR").font(Theme.title(15)).tracking(6).foregroundStyle(Theme.magenta)
                        .shadow(color: Theme.magenta.opacity(0.6), radius: 8)
                }
                .padding(.top, 6)

                hero(s)

                missionCard(s)
                    .padding(.horizontal, 20)
                alertStrip(s)
                    .padding(.horizontal, 20).padding(.top, 10)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    tile("Tech Lab", "wrench.and.screwdriver.fill", Color(red: 0.75, green: 0.5, blue: 1), sub: "Upgrades", badge: nil) { model.go(.lab) }
                        .accessibilityIdentifier("labButton")
                    tile("Endless", "infinity", Theme.magenta, sub: s.endlessUnlocked ? (s.bestEndless > 0 ? "Best \(timeString(s.bestEndless))" : "Survive") : "Clear Heart",
                         badge: s.endlessUnlocked ? nil : "🔒") { if s.endlessUnlocked { model.play(.endless) } }
                        .accessibilityIdentifier("endlessButton")
                    tile("Boss Rush", "flame.fill", Theme.red, sub: s.bossRushUnlocked ? (s.bossRushBest().map { "Best \(timeString($0))" } ?? "This week") : "Save a city",
                         badge: s.bossRushUnlocked ? (s.bossRushBest() == nil ? "NEW" : nil) : "🔒") { if s.bossRushUnlocked { model.play(.bossRush) } }
                        .accessibilityIdentifier("bossRushButton")
                    tile("Pedia", "book.fill", Theme.cyan, sub: "\(s.discovered.intersection(Pedia.ids).count)/\(Pedia.all.count)", badge: nil) { model.go(.pedia) }
                        .accessibilityIdentifier("pediaButton")
                    tile("Allies", "person.2.fill", Theme.lime, sub: s.ally?.title ?? "Pick one", badge: nil) { model.go(.allies) }
                        .accessibilityIdentifier("alliesButton")
                    tile("Skins", "paintpalette.fill", Theme.gold, sub: s.skin.title, badge: s.canAffordNewSkin ? "!" : nil) { model.go(.skins) }
                        .accessibilityIdentifier("skinsButton")
                }
                .padding(.horizontal, 20).padding(.top, 12)

                Spacer(minLength: 8)
                BannerAdView()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { float = true }
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func topBar(_ s: SaveData) -> some View {
        HStack(spacing: 6) {
            CoinBadge(coins: s.coins)
            Button { model.go(.daily) } label: {
                Image(systemName: "star.circle.fill").font(.system(size: 19, weight: .bold)).foregroundStyle(Theme.gold)
                    .frame(width: 40, height: 40).glass(14)
                    .overlay(alignment: .topTrailing) {
                        let n = s.daily.unclaimed
                        if n > 0 {
                            Text("\(n)").font(Theme.body(11, .black)).foregroundStyle(.white)
                                .frame(width: 20, height: 20).background(Circle().fill(Theme.magenta)).offset(x: 6, y: -6)
                        }
                    }
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("dailyButton")
            Button { model.go(.season) } label: {
                Image(systemName: "ticket.fill").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.lime)
                    .frame(width: 40, height: 40).glass(14)
                    .overlay(alignment: .topTrailing) {
                        if s.unclaimedSeasonTiers > 0 {
                            Text("\(s.unclaimedSeasonTiers)").font(Theme.body(11, .black)).foregroundStyle(.white)
                                .frame(width: 20, height: 20).background(Circle().fill(Theme.magenta)).offset(x: 6, y: -6)
                        }
                    }
            }
            .buttonStyle(PressStyle())
            .accessibilityIdentifier("seasonButton")
            Spacer()
            toggle("trophy.fill") { model.go(.trophies) }
                .overlay(alignment: .topTrailing) {
                    if s.unclaimedTrophies > 0 {
                        Text("\(s.unclaimedTrophies)").font(Theme.body(11, .black)).foregroundStyle(.white)
                            .frame(width: 20, height: 20).background(Circle().fill(Theme.magenta)).offset(x: 6, y: -6)
                    }
                }
                .accessibilityIdentifier("trophiesButton")
            toggle(sound ? "speaker.wave.2.fill" : "speaker.slash.fill") { sound.toggle() }.accessibilityIdentifier("soundToggle")
            toggle(haptics ? "iphone.radiowaves.left.and.right" : "iphone.slash") { haptics.toggle() }
        }
    }

    /// Nano with the swarm orbiting, the ally beside, and King Vex lurking behind.
    private func hero(_ s: SaveData) -> some View {
        ZStack {
            Image("king-vex").resizable().scaledToFit().frame(width: 110)
                .opacity(0.35).blur(radius: 1).offset(x: 120, y: -60)
                .scaleEffect(pulse ? 1.05 : 0.95)
            Circle().fill(RadialGradient(colors: [Theme.cyan.opacity(0.35), .clear], center: .center, startRadius: 10, endRadius: 150)).frame(width: 300, height: 300)
            ForEach(0..<5) { i in
                Image(s.skin.botTexture).resizable().frame(width: 30, height: 30)
                    .offset(x: 105)
                    .rotationEffect(.degrees(Double(i) * 72 + (spin ? 360 : 0)))
            }
            Button { model.go(.skins) } label: {
                Image(s.skin.texture(.happy)).resizable().scaledToFit().frame(width: 160)
            }
            .buttonStyle(PressStyle())
            .offset(y: float ? -8 : 6)
            if let a = s.ally {
                Image(a.texture).resizable().scaledToFit().frame(width: 58)
                    .offset(x: -110, y: float ? 40 : 52)
            }
        }
        .frame(height: 195)
        .frame(maxWidth: .infinity)
    }

    /// The outbreak at a glance, with the big Play button.
    private func missionCard(_ s: SaveData) -> some View {
        let country = s.country
        let done = s.citiesCleared >= Organ.maxInfection
        let city = country.city(s.currentCity)
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text(country.flag).font(.system(size: 30))
                VStack(alignment: .leading, spacing: 2) {
                    Text(done ? "\(country.name.uppercased()) IS VIRUS FREE" : "OUTBREAK IN \(city.uppercased())")
                        .font(Theme.body(14, .black)).foregroundStyle(done ? Theme.lime : Theme.red).lineLimit(1).minimumScaleFactor(0.7)
                    Text(done ? "All \(Organ.maxInfection) cities saved" : "City \(s.currentCity) of \(Organ.maxInfection) · \(s.infected(inCity: s.currentCity).formatted()) people infected")
                        .font(Theme.body(12)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                if let next = s.nextMission {
                    VStack(spacing: 0) {
                        Image(next.bossSetup(country: country.id).texture).resizable().scaledToFit().frame(width: 40, height: 40)
                        Text(next.name).font(Theme.body(10, .heavy)).foregroundStyle(.white).lineLimit(1)
                    }
                }
            }
            RecoveryBar(title: country.id == Country.world.id ? "WORLD HEALTH" : "\(country.name.uppercased()) HEALTH", value: Story.recovery(s))
            GameButton(title: s.nextMission.map { "Play · \($0.name)" } ?? "Play", icon: "play.fill", height: 62) { model.go(.map) }
                .accessibilityIdentifier("playButton")
                .scaleEffect(pulse ? 1.02 : 0.99)
        }
        .padding(14).glass(20)
    }

    /// Today's Outbreak Alert: one organ flares up; beating it today pays a bonus once.
    private func alertStrip(_ s: SaveData) -> some View {
        let a = s.outbreakAlert()
        let done = s.alertDone()
        return Button {
            Sound.tap.play(); Haptics.light()
            if !done { model.play(a.organ) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: done ? "checkmark.shield.fill" : "light.beacon.max.fill")
                    .font(.system(size: 20, weight: .bold)).foregroundStyle(done ? Theme.lime : Theme.red)
                    .opacity(done || pulse ? 1 : 0.5)
                VStack(alignment: .leading, spacing: 1) {
                    Text(done ? "OUTBREAK ALERT CONTAINED" : "OUTBREAK ALERT: \(a.organ.name.uppercased())")
                        .font(Theme.body(12, .black)).foregroundStyle(done ? Theme.lime : Theme.red).lineLimit(1).minimumScaleFactor(0.7)
                    Text(done ? "A new alert comes tomorrow" : "\(s.country.city(a.level)) · win today for +\(OutbreakAlert.coinBonus) coins and 🧬 \(OutbreakAlert.dnaBonus)")
                        .font(Theme.body(11)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                if !done { Image(systemName: "play.fill").font(.system(size: 14, weight: .black)).foregroundStyle(.white) }
            }
            .padding(.horizontal, 12).frame(height: 48).glass(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke((done ? Theme.lime : Theme.red).opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(PressStyle())
        .disabled(done)
        .accessibilityIdentifier("alertButton")
    }

    private func tile(_ title: String, _ icon: String, _ color: Color, sub: String, badge: String?, _ action: @escaping () -> Void) -> some View {
        Button { Sound.tap.play(); Haptics.light(); action() } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(color)
                    .shadow(color: color.opacity(0.6), radius: 6)
                Text(title).font(Theme.body(13, .heavy)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                Text(sub).font(Theme.body(10, .semibold)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity).frame(height: 72).glass(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.35), lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge).font(Theme.body(10, .black)).foregroundStyle(.white)
                        .padding(.horizontal, 5).frame(minWidth: 20, minHeight: 20).background(Capsule().fill(Theme.magenta.opacity(0.9))).offset(x: 4, y: -6)
                }
            }
        }
        .buttonStyle(PressStyle())
    }

    private func toggle(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button { action(); Sound.tap.play() } label: {
            Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(.white).frame(width: 40, height: 40).glass(14)
        }
    }
}

func timeString(_ t: Double) -> String { String(format: "%d:%02d", Int(t) / 60, Int(t) % 60) }

/// Slowly drifting viruses behind menus.
struct FloatingViruses: View {
    @State private var t = false
    private let items: [(String, CGFloat, CGFloat, CGFloat, Double)] = [
        ("virus-spiky", 0.12, 0.22, 70, 7), ("virus-mini", 0.86, 0.18, 44, 5), ("virus-blob", 0.9, 0.62, 80, 9),
        ("virus-dart", 0.08, 0.7, 56, 6), ("virus-spitter", 0.75, 0.88, 50, 8), ("virus-mini", 0.25, 0.92, 36, 5.5),
    ]
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<items.count, id: \.self) { i in
                let it = items[i]
                Image(it.0).resizable().frame(width: it.3, height: it.3)
                    .opacity(0.55)
                    .blur(radius: i % 2 == 0 ? 0 : 1.5)
                    .rotationEffect(.degrees(t ? 12 : -12))
                    .position(x: geo.size.width * it.1, y: geo.size.height * it.2 + (t ? -14 : 14))
                    .animation(.easeInOut(duration: it.4).repeatForever(autoreverses: true), value: t)
            }
        }
        .onAppear { t = true }
        .allowsHitTesting(false)
    }
}
