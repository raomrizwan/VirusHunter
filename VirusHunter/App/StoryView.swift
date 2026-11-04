import SwiftUI

/// A story scene waiting to be shown, plus what happens when the player finishes or skips it.
struct ActiveStory: Identifiable {
    let id = UUID()
    let scene: StoryScene
    let onDone: (() -> Void)?
}

/// Comic-style dialogue overlay: portrait, name, typewriter text. Tap to advance, Skip to close.
struct StoryView: View {
    @EnvironmentObject var model: AppModel
    let story: ActiveStory
    var onClose: () -> Void

    @State private var index = 0
    @State private var shown = 0          // characters revealed of the current line
    @State private var typing: Task<Void, Never>?
    @State private var appear = false

    private var line: StoryLine { story.scene.lines[index] }
    private var fullText: String { line.text }
    private var done: Bool { shown >= fullText.count }

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text(story.scene.title.uppercased())
                        .font(Theme.body(13, .heavy)).tracking(2).foregroundStyle(Theme.cyan)
                        .padding(.horizontal, 12).padding(.vertical, 8).glass(12)
                    Spacer()
                    Button { finish() } label: {
                        Label("Skip", systemImage: "forward.fill").font(Theme.body(14, .heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 9).glass(12)
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityIdentifier("storySkip")
                }
                .padding(.horizontal, 18).padding(.top, 10)

                Spacer()

                portrait
                    .frame(maxWidth: .infinity, alignment: line.speaker.onRight ? .trailing : .leading)
                    .padding(.horizontal, 22)
                    .offset(y: 18)
                    .zIndex(1)

                VStack(alignment: .leading, spacing: 10) {
                    Text(line.speaker.name.uppercased())
                        .font(Theme.title(20)).foregroundStyle(color(line.speaker))
                    Text(String(fullText.prefix(shown)))
                        .font(Theme.body(19, .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        HStack(spacing: 5) {
                            ForEach(story.scene.lines.indices, id: \.self) { i in
                                Circle().fill(i == index ? color(line.speaker) : .white.opacity(0.25)).frame(width: 7, height: 7)
                            }
                        }
                        Spacer()
                        if done {
                            Label(index == story.scene.lines.count - 1 ? "Let's go" : "Tap", systemImage: "chevron.right.2")
                                .font(Theme.body(13, .heavy)).foregroundStyle(.white.opacity(0.75))
                                .transition(.opacity)
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 24).fill(Theme.panel.opacity(0.95))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(color(line.speaker).opacity(0.7), lineWidth: 2))
                )
                .shadow(color: color(line.speaker).opacity(0.35), radius: 18)
                .padding(.horizontal, 16).padding(.bottom, 26)
            }
            .opacity(appear ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .accessibilityIdentifier("storyView")
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) { appear = true }
            type()
        }
        .onDisappear { typing?.cancel() }
    }

    private var portrait: some View {
        let s = line.speaker
        let image = s == .nano ? model.save.skin.texture(.happy) : s.portrait
        return Image(image).resizable().scaledToFit().frame(width: 170, height: 170)
            .shadow(color: color(s).opacity(0.6), radius: 16)
            .id(index) // re-run the entrance for each line
            .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
    }

    private func color(_ s: Speaker) -> Color {
        switch s {
        case .nano: return Theme.cyan
        case .leuko: return Color(red: 0.78, green: 0.72, blue: 1)
        case .vex: return Theme.red
        }
    }

    private func type() {
        typing?.cancel()
        shown = 0
        let total = fullText.count
        typing = Task { @MainActor in
            while shown < total {
                try? await Task.sleep(nanoseconds: 22_000_000)
                if Task.isCancelled { return }
                shown += 1
            }
        }
    }

    private func advance() {
        if !done { typing?.cancel(); shown = fullText.count; return }
        Sound.tap.play(); Haptics.light()
        if index + 1 < story.scene.lines.count {
            withAnimation(.spring(duration: 0.35, bounce: 0.35)) { index += 1 }
            type()
        } else {
            finish()
        }
    }

    private func finish() {
        typing?.cancel()
        onClose()
    }
}

/// The Story journal: every scene seen so far, replayable from the Body Map.
struct StoryJournal: View {
    @EnvironmentObject var model: AppModel
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea().onTapGesture { onClose() }
            VStack(spacing: 14) {
                HStack {
                    Text("STORY").font(Theme.title(24)).foregroundStyle(.white)
                    Spacer()
                    Button { onClose() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .heavy)).foregroundStyle(.white).frame(width: 40, height: 40).glass(12)
                    }
                    .buttonStyle(PressStyle())
                }
                RecoveryBar(title: model.save.country.id == Country.world.id ? "WORLD HEALTH" : "\(model.save.country.name.uppercased()) HEALTH",
                            value: Story.recovery(model.save))
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Story.scenes) { s in
                            let seen = model.save.seenStory.contains(s.id)
                            let title = Story.resolve(s, country: model.save.country, city: Story.city(for: s.id)).title
                            Button {
                                if seen { model.replayStory(s) }
                            } label: {
                                HStack {
                                    Image(systemName: seen ? "play.circle.fill" : "lock.fill")
                                        .foregroundStyle(seen ? Theme.cyan : .white.opacity(0.35))
                                    Text(seen ? title : "???").font(Theme.body(16, .bold)).foregroundStyle(seen ? .white : .white.opacity(0.35))
                                    Spacer()
                                }
                                .padding(14).glass(14)
                            }
                            .buttonStyle(PressStyle())
                            .disabled(!seen)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxHeight: 620)
            .background(RoundedRectangle(cornerRadius: 26).fill(Theme.bg.opacity(0.96)))
            .padding(18)
        }
    }
}

/// Country health bar: how much of the outbreak has been cured.
struct RecoveryBar: View {
    let title: String
    let value: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: "heart.text.square.fill").font(Theme.body(12, .heavy)).tracking(1.5).foregroundStyle(Theme.lime)
                Spacer()
                Text("\(Int((value * 100).rounded()))%").font(Theme.body(13, .heavy)).foregroundStyle(.white).monospacedDigit()
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule().fill(LinearGradient(colors: [Theme.red, Theme.gold, Theme.lime], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, g.size.width * value))
                }
            }
            .frame(height: 8)
        }
        .padding(12).glass(14)
        .accessibilityIdentifier("recoveryBar")
    }
}
