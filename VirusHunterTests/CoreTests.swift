import XCTest
@testable import VirusHunter

final class CoreTests: XCTestCase {
    func testStartLoadoutHasLaser() {
        let l = Loadout()
        XCTAssertEqual(l.level(.laser), 1)
        XCTAssertEqual(l.weaponOrder, [.laser])
    }

    func testRollGivesThreeDistinctOptions() {
        var rng = SystemRandomNumberGenerator()
        let l = Loadout()
        for _ in 0..<50 {
            let o = l.rollOptions(rng: &rng)
            XCTAssertEqual(o.count, 3)
            XCTAssertEqual(Set(o.map(\.id)).count, 3)
        }
    }

    func testWeaponCapAtFour() {
        var l = Loadout()
        for w in [WeaponKind.swarm, .shield, .field] { l.apply(.weapon(w, toLevel: 1)) }
        XCTAssertEqual(l.weapons.count, 4)
        XCTAssertFalse(l.candidates().contains(.weapon(.zap, toLevel: 1)))
        XCTAssertTrue(l.candidates().contains(.weapon(.swarm, toLevel: 2)))
    }

    func testMaxedLoadoutFallsBackToHealAndCoins() {
        var l = Loadout()
        for w in [WeaponKind.laser, .swarm, .shield, .field] { l.apply(.weapon(w, toLevel: 5)) }
        for p in PassiveKind.allCases { l.apply(.passive(p, toLevel: 5)) }
        var rng = SystemRandomNumberGenerator()
        let o = l.rollOptions(rng: &rng)
        XCTAssertEqual(o.count, 3)
        XCTAssertTrue(o.contains(.heal))
        XCTAssertTrue(o.contains(.coins(25)))
    }

    func testXPCurveGrows() {
        XCTAssertLessThan(xpToNext(1), xpToNext(5))
        XCTAssertLessThan(xpToNext(5), xpToNext(20))
        XCTAssertEqual(xpToNext(1), 8)
    }

    func testTechLabPurchase() {
        var s = SaveData(); s.coins = 100
        XCTAssertTrue(s.buy(.power))
        XCTAssertEqual(s.level(.power), 1)
        XCTAssertEqual(s.coins, 40)
        XCTAssertFalse(s.buy(.revive))
    }

    func testStatsCombineLabAndPassives() {
        var s = SaveData(); s.tech = ["health": 2, "power": 4]
        var l = Loadout(); l.apply(.passive(.maxHP, toLevel: 2)); l.apply(.passive(.power, toLevel: 1))
        let p = PlayerStats.make(save: s, loadout: l)
        XCTAssertEqual(p.maxHP, 160)
        XCTAssertEqual(p.damage, 1.3, accuracy: 0.0001)
    }

    func testFreshPlayerOutrunsRegularViruses() {
        // No Tech Lab and no passives: Nano must still be clearly faster than any regular virus at max jitter.
        let p = PlayerStats.make(save: SaveData(), loadout: Loadout())
        for kind in [EnemyKind.spiky, .mini, .blob, .dart, .spitter, .elite] {
            XCTAssertGreaterThan(p.speed, kind.base.speed * 1.12 * 1.75, "\(kind)")
        }
    }

    func testSpawnerUnlocksKindsOverTime() {
        XCTAssertFalse(Spawner.kinds(time: 10).contains { $0.0 == .blob })
        XCTAssertTrue(Spawner.kinds(time: 150).contains { $0.0 == .spitter })
        XCTAssertGreaterThan(Spawner.rate(time: 200, organ: Organ.all[0]), Spawner.rate(time: 0, organ: Organ.all[0]))
    }

    func testOrgansAndCoins() {
        XCTAssertEqual(Organ.all.count, 5)
        XCTAssertEqual(runCoins(collected: 10, kills: 100, cleared: Organ.all[0], bonus: 1), 10 + 10 + 90)
        XCTAssertGreaterThan(Organ.all[4].difficulty, Organ.all[0].difficulty)
    }

    func testSaveRoundTrip() {
        let d = UserDefaults(suiteName: "vh-test")!
        d.removePersistentDomain(forName: "vh-test")
        let store = SaveStore(defaults: d)
        var s = SaveData(); s.coins = 77; s.clearedStages = [1]; s.tech = ["speed": 3]
        store.save(s)
        XCTAssertEqual(store.load(), s)
    }
}
