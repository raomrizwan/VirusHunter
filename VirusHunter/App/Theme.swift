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
struct GameButton: View {
    let title: String
    var icon: String?
    var colors: [Color] = [Color(red: 0.35, green: 1, blue: 0.6), Color(red: 0.05, green: 0.7, blue: 0.45)]
    var height: CGFloat = 64
    var action: () -> Void
    @State private var pressed = false
    var body: some View {
        Button {
            Sound.tap.play(); Haptics.light(); action()
        } label: {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon).font(.system(size: height * 0.34, weight: .heavy)) }
                Text(title).font(Theme.title(height * 0.34)).textCase(.uppercase)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 0, y: 2)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: height * 0.32, style: .continuous).fill(colors.last!.opacity(0.9)).offset(y: 5)
                    RoundedRectangle(cornerRadius: height * 0.32, style: .continuous).fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                    RoundedRectangle(cornerRadius: height * 0.32, style: .continuous).fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center)).padding(3)
                }
            )
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
