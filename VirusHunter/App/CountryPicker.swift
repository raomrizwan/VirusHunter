import SwiftUI

/// "Where are you from?": picks the country whose 10 main cities become the outbreak campaign.
struct CountryPicker: View {
    @EnvironmentObject var model: AppModel
    @State private var selected: String = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 14) {
                Image("king-vex").resizable().scaledToFit().frame(width: 96, height: 96)
                    .shadow(color: Theme.red.opacity(0.6), radius: 14)
                Text("WHERE ARE YOU FROM?").font(Theme.title(26)).foregroundStyle(.white).multilineTextAlignment(.center)
                Text("King Vex is starting an outbreak in your country. Nano will save its main cities one by one.")
                    .font(Theme.body(15, .medium)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Country.all) { c in
                            Button {
                                selected = c.id; Sound.tap.play(); Haptics.light()
                            } label: {
                                HStack(spacing: 12) {
                                    Text(c.flag).font(.system(size: 30))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.name).font(Theme.body(17, .heavy)).foregroundStyle(.white)
                                        Text(c.cities.prefix(3).joined(separator: " · ") + " ...")
                                            .font(Theme.body(12)).foregroundStyle(Theme.muted).lineLimit(1)
                                    }
                                    Spacer()
                                    let saved = model.save.citiesSaved(in: c.id)
                                    if saved > 0 {
                                        Text("\(saved)/\(Organ.maxInfection)").font(Theme.body(12, .heavy)).foregroundStyle(saved >= Organ.maxInfection ? Theme.gold : Theme.lime)
                                            .padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(.white.opacity(0.1)))
                                    }
                                    if selected == c.id {
                                        Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.lime)
                                    }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 16).fill(selected == c.id ? Theme.lime.opacity(0.18) : .white.opacity(0.06)))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected == c.id ? Theme.lime : .clear, lineWidth: 2))
                            }
                            .buttonStyle(PressStyle())
                            .accessibilityIdentifier("country-\(c.id)")
                        }
                    }
                }
                GameButton(title: "Start mission", icon: "location.fill", height: 60) {
                    Sound.levelup.play(); Haptics.success()
                    model.setCountry(selected.isEmpty ? Country.world.id : selected)
                }
                .accessibilityIdentifier("countryConfirm")
                if model.save.countryCode != nil {
                    Text("Every country is its own campaign. Your progress in other countries is kept, and so are your upgrades.")
                        .font(Theme.body(12)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                    Button("Cancel") { withAnimation { model.pickingCountry = false } }
                        .font(Theme.body(15, .bold)).foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(20)
            .frame(maxWidth: 520)
        }
        .onAppear {
            // Default to the saved country, else the device region, else the World Tour.
            let device = Locale.current.region?.identifier
            selected = model.save.countryCode ?? Country.find(device).id
        }
    }
}
