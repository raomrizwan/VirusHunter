import AVFoundation

/// Tiny sound-effect player. Keeps a small pool of AVAudioPlayers per effect so
/// rapid events (several snaps in one move) can overlap.
enum Sound: String, CaseIterable {
    case shoot, hit, kill, pickup, coin, levelup, hurt, zap, bomb, warning, victory, defeat, tap, stomp

    static var enabled: Bool { UserDefaults.standard.object(forKey: "sound") as? Bool ?? true }

    /// Only touched on `queue`.
    private static var pools: [Sound: [AVAudioPlayer]] = [:]
    private static var configured = false

    private static let queue = DispatchQueue(label: "sound", qos: .userInitiated)

    /// Audio session + players are created off the main thread (AVAudioSession can block).
    static func preload() {
        guard !configured else { return }
        configured = true
        queue.async {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            var loaded: [Sound: [AVAudioPlayer]] = [:]
            for s in allCases {
                guard let url = Bundle.main.url(forResource: s.rawValue, withExtension: "wav") else { continue }
                var pool: [AVAudioPlayer] = []
                for _ in 0..<4 {
                    if let p = try? AVAudioPlayer(contentsOf: url) { p.prepareToPlay(); pool.append(p) }
                }
                loaded[s] = pool
            }
            pools = loaded
        }
    }

    private static var lastPlayed: [Sound: CFTimeInterval] = [:]

    /// Plays the effect; `minGap` throttles very frequent sounds (kills, pickups).
    func play(volume: Float = 1, minGap: CFTimeInterval = 0) {
        guard Sound.enabled else { return }
        let now = CACurrentMediaTime()
        if minGap > 0, let last = Sound.lastPlayed[self], now - last < minGap { return }
        Sound.lastPlayed[self] = now
        Sound.preload()
        // AVAudioPlayer.play() can take milliseconds; keep it off the game loop.
        Sound.queue.async {
            guard let pool = Sound.pools[self] else { return }
            let p = pool.first { !$0.isPlaying } ?? pool.first
            p?.volume = volume
            p?.currentTime = 0
            p?.play()
        }
    }
}
