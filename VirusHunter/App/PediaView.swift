import SwiftUI

/// Virus-pedia: a collection of every character met so far. Unknown ones show as dark silhouettes.
struct PediaView: View {
    @EnvironmentObject var model: AppModel
    @State private var selected: PediaEntry?

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    var body: some View {
        let found = model.save.discovered
        let total = Pedia.all.count
        let have = Pedia.all.filter { found.contains($0.id) }.count
        ZStack {
            MenuBackground(tint: Theme.cyan)
            VStack(spacing: 12) {
                HStack {
                    Button { model.go(.home) } label: {
                        Image(systemName: "chevron.left").font(.system(size: 18, weight: .heavy)).foregroundStyle(.white).frame(width: 44, height: 44).glass(14)
                    }
                    .accessibilityIdentifier("backButton")
                    Spacer()
                    Text("VIRUS-PEDIA").font(Theme.title(24)).foregroundStyle(.white)
                    Spacer()
                    CoinBadge(coins: model.save.coins)
                }
                .padding(.horizontal, 20).padding(.top, 6)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("\(have) / \(total) found", systemImage: "book.fill").font(Theme.body(15, .heavy)).foregroundStyle(Theme.cyan)
                        Spacer()
                        Text("+\(Pedia.coinsPerCard) coins per new card").font(Theme.body(12, .bold)).foregroundStyle(Theme.muted)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.12))
                            Capsule().fill(Theme.cyan).frame(width: max(6, g.size.width * Double(have) / Double(max(1, total))))
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(PediaEntry.Group.allCases, id: \.self) { g in
                            let items = Pedia.all.filter { $0.group == g }
                            let n = items.filter { found.contains($0.id) }.count
                            Text("\(g.rawValue.uppercased())  \(n)/\(items.count)").font(Theme.body(13, .heavy)).tracking(1.5).foregroundStyle(Theme.muted)
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(items) { card($0, known: found.contains($0.id)) }
                            }
                        }
                    }
                    .padding(.horizontal, 18).padding(.bottom, 30)
                }
            }
            if let e = selected { detail(e) }
        }
    }

    private func card(_ e: PediaEntry, known: Bool) -> some View {
        Button {
            guard known else { Haptics.error(); return }
            Sound.tap.play(); withAnimation(.spring(duration: 0.3)) { selected = e }
        } label: {
            VStack(spacing: 4) {
                Image(e.id).resizable().scaledToFit().frame(width: 64, height: 64)
                    .colorMultiply(known ? .white : .black).opacity(known ? 1 : 0.55)
                Text(known ? e.name : "???").font(Theme.body(11, .heavy)).foregroundStyle(known ? .white : .white.opacity(0.4))
                    .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.7).frame(height: 28)
            }
            .padding(8).frame(maxWidth: .infinity).glass(14)
        }
        .buttonStyle(PressStyle())
    }

    private func detail(_ e: PediaEntry) -> some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea().onTapGesture { withAnimation { selected = nil } }
            VStack(spacing: 12) {
                Image(e.id).resizable().scaledToFit().frame(width: 180, height: 180).shadow(color: Theme.cyan.opacity(0.5), radius: 18)
                Text(e.group.rawValue.uppercased()).font(Theme.body(12, .heavy)).tracking(2).foregroundStyle(Theme.cyan)
                Text(e.name).font(Theme.title(28)).foregroundStyle(.white).multilineTextAlignment(.center)
                Text(e.line).font(Theme.body(16, .medium)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                GameButton(title: "Close", kind: .secondary, height: 50) { withAnimation { selected = nil } }
            }
            .padding(24).frame(maxWidth: 380)
            .background(RoundedRectangle(cornerRadius: 26).fill(Theme.bg.opacity(0.97)))
            .padding(24)
        }
        .transition(.opacity)
    }
}
