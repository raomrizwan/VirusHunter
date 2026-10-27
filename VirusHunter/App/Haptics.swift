import UIKit

enum Haptics {
    static var enabled: Bool { UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true }
    private static let lightGen = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGen = UIImpactFeedbackGenerator(style: .medium)
    private static let softGen = UIImpactFeedbackGenerator(style: .soft)
    private static let notifyGen = UINotificationFeedbackGenerator()

    static func light() { guard enabled else { return }; lightGen.impactOccurred() }
    static func medium() { guard enabled else { return }; mediumGen.impactOccurred() }
    static func soft() { guard enabled else { return }; softGen.impactOccurred() }
    static func success() { guard enabled else { return }; notifyGen.notificationOccurred(.success) }
    static func error() { guard enabled else { return }; notifyGen.notificationOccurred(.error) }
}
