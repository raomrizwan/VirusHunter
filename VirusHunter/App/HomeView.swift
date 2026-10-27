import SwiftUI

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage("sound") private var sound = true
    @AppStorage("haptics") private var haptics = true
    @State private var float = false
    @State private var spin = false

    var body: some View {
        ZStack {
            MenuBackground()
            FloatingViruses()
            VStack(spacing: 0) {
                HStack {
                    CoinBadge(coins: model.save.coins)
                    Spacer()
                    toggle(sound ? "speaker.wave.2.fill" : "speaker.slash.fill") { sound.toggle() }.accessibilityIdentifier("soundToggle")
                    toggle(haptics ? "iphone.radiowaves.left.and.right" : "iphone.slash") { haptics.toggle() }
                }
                .padding(.horizontal, 20).padding(.top, 8)

                Spacer(minLength: 10)
                VStack(spacing: 2) {
                    Text("VIRUS HUNTER")
                        .font(Theme.title(44))
                        .foregroundStyle(LinearGradient(colors: [.white, Theme.cyan], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Theme.cyan.opacity(0.7), radius: 16)
                    Text("NANO SWARM")
                        .font(Theme.title(18)).tracking(6)
                        .foregroundStyle(Theme.magenta)
                        .shadow(color: Theme.magenta.opacity(0.6), radius: 8)
                }
                .padding(.top, 10)

                ZStack {
                    Circle().fill(RadialGradient(colors: [Theme.cyan.opacity(0.35), .clear], center: .center, startRadius: 10, endRadius: 170)).frame(width: 340, height: 340)
                    ForEach(0..<5) { i in
                        Image("minibot").resizable().frame(width: 34, height: 34)
                            .offset(x: 120)
                            .rotationEffect(.degrees(Double(i) * 72 + (spin ? 360 : 0)))
                    }
                    Image("nano-happy").resizable().scaledToFit().frame(width: 210)
                        .offset(y: float ? -10 : 8)
                }
                .frame(height: 300)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { float = true }
                    withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) { spin = true }
                }

                Spacer(minLength: 10)
                VStack(spacing: 14) {
                    GameButton(title: "Play", icon: "play.fill", height: 72) { model.go(.map) }
                        .accessibilityIdentifier("playButton")
                    HStack(spacing: 14) {
                        GameButton(title: "Tech Lab", icon: "wrench.and.screwdriver.fill",
                                   colors: [Color(red: 0.75, green: 0.5, blue: 1), Color(red: 0.45, green: 0.2, blue: 0.9)], height: 56) { model.go(.lab) }
                            .accessibilityIdentifier("labButton")
                        GameButton(title: "Endless", icon: "infinity",
                                   colors: model.save.endlessUnlocked ? [Color(red: 1, green: 0.55, blue: 0.75), Color(red: 0.9, green: 0.2, blue: 0.5)] : [.gray, Color(white: 0.3)],
                                   height: 56) {
                            if model.save.endlessUnlocked { model.go(.game(.endless)) }
                        }
                        .overlay(alignment: .topTrailing) {
                            if !model.save.endlessUnlocked {
                                Image(systemName: "lock.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(.white).padding(6).background(Circle().fill(.black.opacity(0.5))).offset(x: 6, y: -8)
                            }
                        }
                    }
                    if !model.save.endlessUnlocked {
                        Text("Clear the Heart to unlock Endless").font(Theme.body(13)).foregroundStyle(Theme.muted)
                    } else if model.save.bestEndless > 0 {
                        Text("Best endless: \(timeString(model.save.bestEndless))").font(Theme.body(13)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(.horizontal, 28)
                Spacer(minLength: 14)
                BannerAdView()
            }
        }
    }

    private func toggle(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button { action(); Sound.tap.play() } label: {
            Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(.white).frame(width: 42, height: 42).glass(14)
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

struct IntroView: View {
    @EnvironmentObject var model: AppModel
    @State private var page = 0
    private let pages: [(String, String, String)] = [
        ("virus-spiky", "Year 2150", "A digital super-virus has infected the human body. Billions of viruses. One body at risk."),
        ("nano-happy", "Meet Nano", "A tiny medical nanobot, built as humanity's last hope."),
        ("nano-fight", "Survive the Swarm", "Drag to fly. Nano fires by itself. Collect DNA, level up, and build your own nano arsenal."),
    ]
    var body: some View {
        ZStack {
            MenuBackground(tint: page == 0 ? Theme.lime : Theme.cyan)
            VStack(spacing: 24) {
                HStack { Spacer(); Button("Skip") { done() }.font(Theme.body(16)).foregroundStyle(Theme.muted).padding() }
                Spacer()
                Image(pages[page].0).resizable().scaledToFit().frame(width: 230, height: 230)
                    .shadow(color: (page == 0 ? Theme.lime : Theme.cyan).opacity(0.6), radius: 30)
                    .id(page).transition(.scale.combined(with: .opacity))
                Text(pages[page].1).font(Theme.title(34)).foregroundStyle(.white)
                Text(pages[page].2).font(Theme.body(18, .medium)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).padding(.horizontal, 36)
                Spacer()
                HStack(spacing: 8) { ForEach(0..<pages.count, id: \.self) { i in Capsule().fill(i == page ? Theme.cyan : .white.opacity(0.25)).frame(width: i == page ? 24 : 8, height: 8) } }
                GameButton(title: page < pages.count - 1 ? "Next" : "Start", icon: page < pages.count - 1 ? "chevron.right" : "play.fill") {
                    if page < pages.count - 1 { withAnimation(.spring) { page += 1 } } else { done() }
                }
                .padding(.horizontal, 28).padding(.bottom, 24)
                .accessibilityIdentifier("introNext")
            }
        }
    }
    private func done() { model.save.seenIntro = true; model.persist(); model.go(.home) }
}
