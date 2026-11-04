import SwiftUI

/// The campaign map: the active country's cities along the top, Patient Zero's body below.
/// Each city is one Infection Level; clearing all five organs there saves the city.
struct MapView: View {
    @EnvironmentObject var model: AppModel
    @State private var selected: Int = 1     // organ id
    @State private var city: Int = 1         // city = Infection Level
    @State private var pulse = false
    @State private var journal = false

    // Organ positions on the body art (fractions of the image).
    private let spots: [Int: CGPoint] = [1: CGPoint(x: 0.42, y: 0.32), 2: CGPoint(x: 0.58, y: 0.37), 3: CGPoint(x: 0.48, y: 0.48),
                                         4: CGPoint(x: 0.5, y: 0.12), 5: CGPoint(x: 0.41, y: 0.76)]

    private var country: Country { model.save.country }

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
                    VStack(spacing: 0) {
                        Text("PATIENT ZERO").font(Theme.body(11, .heavy)).tracking(2).foregroundStyle(Theme.magenta)
                        Text(country.city(city).uppercased()).font(Theme.title(22)).foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    Spacer()
                    CoinBadge(coins: model.save.coins)
                }
                .padding(.horizontal, 20).padding(.top, 6)

                HStack(spacing: 8) {
                    Button { withAnimation { model.pickingCountry = true } } label: {
                        Text(country.flag).font(.system(size: 24)).frame(width: 44, height: 44).glass(14)
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier("countryButton")
                    cityStrip
                    Button { withAnimation { journal = true } } label: {
                        Image(systemName: "book.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.gold).frame(width: 44, height: 44).glass(14)
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier("storyButton")
                }
                .padding(.horizontal, 16)

                cityStatus.padding(.horizontal, 20)

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

                card(Organ.all[selected - 1].at(infection: city)).padding(.horizontal, 20).padding(.bottom, 16)
            }
            if journal {
                StoryJournal { withAnimation { journal = false } }.transition(.opacity)
            }
        }
        .onAppear {
            focusActiveCity()
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { model.checkMapStory() }
        }
        .onChange(of: model.save.countryCode) { _, _ in focusActiveCity() }
    }

    private func focusActiveCity() {
        city = model.save.currentCity
        if let next = model.save.nextMission, next.infection == city { selected = next.id }
        else { selected = min(model.save.unlockedStage, 5) }
    }

    // MARK: cities

    private var cityStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1...Organ.maxInfection, id: \.self) { lv in cityChip(lv).id(lv) }
                }
                .padding(.vertical, 4).padding(.horizontal, 2)
            }
            .onAppear { proxy.scrollTo(model.save.currentCity, anchor: .center) }
            .onChange(of: city) { _, c in withAnimation { proxy.scrollTo(c, anchor: .center) } }
        }
    }

    private func cityChip(_ lv: Int) -> some View {
        let saved = model.save.citiesCleared >= lv
        let open = lv <= model.save.currentCity
        let isSel = lv == city
        let color: Color = saved ? Theme.lime : open ? Theme.magenta : .gray
        return Button {
            guard open else { Haptics.error(); return }
            city = lv
            if !model.save.canPlay(selected, level: lv) { selected = 1 }
            Sound.tap.play(); Haptics.light()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: saved ? "checkmark.shield.fill" : open ? "exclamationmark.triangle.fill" : "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(open ? country.city(lv) : "City \(lv)").font(Theme.body(13, .heavy)).lineLimit(1)
            }
            .foregroundStyle(open ? .white : .white.opacity(0.4))
            .padding(.horizontal, 12).frame(height: 36)
            .background(Capsule().fill(color.opacity(isSel ? 0.45 : 0.15)))
            .overlay(Capsule().stroke(color, lineWidth: isSel ? 2.5 : 1))
            .scaleEffect(!saved && open && !isSel && pulse ? 1.05 : 1)
        }
        .buttonStyle(PressStyle())
        .accessibilityIdentifier("city\(lv)")
    }

    private var cityStatus: some View {
        let infected = model.save.infected(inCity: city)
        let done = model.save.organsCleared(inCity: city)
        return HStack(spacing: 10) {
            Label(infected == 0 ? "City saved" : "\(infected.formatted()) infected",
                  systemImage: infected == 0 ? "checkmark.seal.fill" : "allergens")
                .font(Theme.body(14, .heavy)).foregroundStyle(infected == 0 ? Theme.lime : Theme.red)
            Spacer()
            HStack(spacing: 3) {
                ForEach(0..<Organ.all.count, id: \.self) { i in
                    Capsule().fill(i < done ? Theme.lime : .white.opacity(0.15)).frame(width: 14, height: 6)
                }
            }
            Text("\(done)/\(Organ.all.count) organs clean").font(Theme.body(12, .bold)).foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 14).padding(.vertical, 9).glass(14)
        .accessibilityIdentifier("cityStatus")
    }

    // MARK: organs

    private func organDot(_ o: Organ) -> some View {
        let unlocked = model.save.canPlay(o.id, level: city)
        let cleared = model.save.clearedInfection(o.id) >= city
        let isSel = o.id == selected
        let color: Color = cleared ? Theme.lime : unlocked ? Theme.magenta : .gray
        return Button {
            if unlocked || cleared { selected = o.id; Sound.tap.play(); Haptics.light() }
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
        let playable = model.save.canPlay(o.id, level: o.infection)
        let cleared = model.save.clearedInfection(o.id) >= o.infection
        return HStack(spacing: 14) {
            Image(o.boss.texture).resizable().frame(width: 84, height: 84).shadow(color: Theme.magenta.opacity(0.5), radius: 10)
            VStack(alignment: .leading, spacing: 4) {
                Text(o.infection == 1 ? Story.chapter(o.id).uppercased() : "MUTATED STRAIN · LEVEL \(o.infection)")
                    .font(Theme.body(11, .heavy)).foregroundStyle(o.infection == 1 ? Theme.cyan : Theme.magenta).tracking(1.5)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(o.name).font(Theme.title(26)).foregroundStyle(.white)
                Text("Boss: \(o.boss.bossTitle)").font(Theme.body(14)).foregroundStyle(Theme.muted)
                if o.infection > 1 {
                    Text("Viruses +\(Int((o.difficulty / o.at(infection: 1).difficulty - 1) * 100))% stronger · \(String(format: "%.1f", Double(o.coinReward) / Double(o.at(infection: 1).coinReward)))x coins")
                        .font(Theme.body(12, .medium)).foregroundStyle(Theme.muted).lineLimit(1).minimumScaleFactor(0.7)
                }
                if cleared {
                    Label("Cleared", systemImage: "checkmark.seal.fill").font(Theme.body(13, .bold)).foregroundStyle(Theme.lime)
                }
            }
            Spacer(minLength: 0)
            Button {
                Sound.tap.play(); Haptics.medium(); model.play(o)
            } label: {
                Image(systemName: playable ? "play.fill" : "lock.fill").font(.system(size: 26, weight: .black)).foregroundStyle(.white)
                    .frame(width: 66, height: 66)
                    .background(Circle().fill(playable
                        ? LinearGradient(colors: [Color(red: 0.35, green: 1, blue: 0.6), Color(red: 0.05, green: 0.7, blue: 0.45)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [.gray, Color(white: 0.3)], startPoint: .top, endPoint: .bottom)))
                    .shadow(color: Theme.lime.opacity(playable ? 0.6 : 0), radius: 10)
            }
            .buttonStyle(PressStyle())
            .disabled(!playable)
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
