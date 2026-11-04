import SwiftUI
import UIKit

enum Theme {
    static let bg = Color(red: 0.03, green: 0.05, blue: 0.10)
    static let panel = Color(red: 0.08, green: 0.12, blue: 0.22)
    static let cyan = Color(red: 0.25, green: 0.90, blue: 1.0)
    static let magenta = Color(red: 1.0, green: 0.35, blue: 0.80)
    static let lime = Color(red: 0.55, green: 1.0, blue: 0.35)
    static let gold = Color(red: 1.0, green: 0.82, blue: 0.25)
    static let red = Color(red: 1.0, green: 0.30, blue: 0.40)
    static let muted = Color.white.opacity(0.62)

    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func body(_ size: CGFloat, _ w: Font.Weight = .semibold) -> Font { .system(size: size, weight: w, design: .rounded) }
}

/// Deep "microscope" background used behind menus.
struct MenuBackground: View {
    var tint: Color = Theme.cyan
    var image: String = "bg-endless"
    var body: some View {
        ZStack {
            Theme.bg
            Image(image).resizable(resizingMode: .tile).opacity(0.55)
            RadialGradient(colors: [tint.opacity(0.25), .clear], center: .top, startRadius: 10, endRadius: 520)
            LinearGradient(colors: [.clear, Theme.bg.opacity(0.9)], startPoint: .center, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }
}

struct GlassPanel: ViewModifier {
    var radius: CGFloat = 22
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(Theme.panel.opacity(0.6), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
    }
}
extension View { func glass(_ r: CGFloat = 22) -> some View { modifier(GlassPanel(radius: r)) } }

/// Big glossy game button.
/// One button family for the whole game, in the neon look of the arena:
/// `.primary` (cyan to blue, the main action), `.reward` (gold, coins and gifts) and
/// `.secondary` (dark glass with a thin outline, for Continue, Quit, Close).
struct GameButton: View {
    enum Kind { case primary, reward, secondary }
    let title: String
    var icon: String?
    var kind: Kind = .primary
    var height: CGFloat = 64
    var action: () -> Void

    private var gradient: [Color] {
        switch kind {
        case .primary: return [Color(red: 0.3, green: 0.92, blue: 1), Color(red: 0.2, green: 0.45, blue: 1)]
        case .reward: return [Color(red: 1, green: 0.86, blue: 0.35), Color(red: 1, green: 0.55, blue: 0.2)]
        case .secondary: return [Color.white.opacity(0.10), Color.white.opacity(0.05)]
        }
    }
    private var glow: Color {
        switch kind {
        case .primary: return Theme.cyan
        case .reward: return Theme.gold
        case .secondary: return .clear
        }
    }

    var body: some View {
        let r = height * 0.32
        Button {
            Sound.tap.play(); Haptics.light(); action()
        } label: {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon).font(.system(size: height * (kind == .secondary ? 0.28 : 0.32), weight: .heavy)) }
                Text(title).font(Theme.title(height * (kind == .secondary ? 0.3 : 0.33))).textCase(.uppercase)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .foregroundStyle(kind == .secondary ? Color.white.opacity(0.88) : .white)
            .shadow(color: .black.opacity(kind == .secondary ? 0 : 0.3), radius: 2, y: 1)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                ZStack {
                    if kind == .secondary {
                        RoundedRectangle(cornerRadius: r, style: .continuous).fill(.ultraThinMaterial).opacity(0.6)
                    }
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    // Glossy top edge
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(kind == .secondary ? 0.08 : 0.28), .clear], startPoint: .top, endPoint: .center))
                        .padding(2)
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .stroke(kind == .secondary ? Color.white.opacity(0.22) : Color.white.opacity(0.45), lineWidth: kind == .secondary ? 1 : 1.2)
                }
            )
            .shadow(color: glow.opacity(0.55), radius: 12, y: 3)
        }
        .buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.95 : 1).animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

struct CoinBadge: View {
    let coins: Int
    var body: some View {
        HStack(spacing: 6) {
            Image("coin").resizable().frame(width: 22, height: 22)
            Text("\(coins)").font(Theme.body(17, .heavy)).foregroundStyle(.white).monospacedDigit()
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .glass(16)
    }
}
