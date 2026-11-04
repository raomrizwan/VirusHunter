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
        // Maxed weapons with their partner passive offer evolutions first...
        XCTAssertEqual(Set(l.candidates()), Set([WeaponKind.laser, .swarm, .shield, .field].map { UpgradeOption.weapon($0, toLevel: evolvedLevel) }))
        // ...and once everything is evolved, only the fallbacks remain.
        for w in [WeaponKind.laser, .swarm, .shield, .field] { l.apply(.weapon(w, toLevel: evolvedLevel)) }
        XCTAssertTrue(l.candidates().isEmpty)
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

    func testOldSaveWithoutSkinsStillLoads() {
        let json = #"{"coins":321,"unlockedStage":2,"clearedStages":[1],"bestEndless":0,"tech":{"power":2},"runs":4,"totalKills":900,"soundOn":true,"hapticsOn":true,"seenIntro":true}"#
        let s = try! JSONDecoder().decode(SaveData.self, from: Data(json.utf8))
        XCTAssertEqual(s.coins, 321)
        XCTAssertEqual(s.level(.power), 2)
        XCTAssertEqual(s.skin, .classic)
        XCTAssertTrue(s.ownedSkins.isEmpty)
    }

    func testSkinsBuyEquipAndEarn() {
        var s = SaveData(); s.coins = 300
        XCTAssertTrue(s.owns(.classic))
        XCTAssertFalse(s.buy(.stealth))
        XCTAssertTrue(s.buy(.neon))
        XCTAssertEqual(s.coins, 50)
        s.equip(.neon)
        XCTAssertEqual(s.skin, .neon)
        XCTAssertFalse(s.buy(.gold))
        s.equip(.gold)
        XCTAssertEqual(s.skin, .neon)
        s.clearedStages = [1, 2, 3]
        XCTAssertTrue(s.owns(.gold))
    }

    func testNextGoalIsCheapestLockedSkin() {
        var s = SaveData()
        XCTAssertEqual(s.nextGoal?.title, Skin.neon.title)
        s.ownedSkins = ["neon", "toxic", "stealth"]
        XCTAssertNotNil(s.nextGoal?.symbol) // falls back to a Tech Lab upgrade
    }

    func testRookieLevelsFasterAndOffersSwarm() {
        XCTAssertLessThan(Rookie.xpNeeded(1), xpToNext(1))
        XCTAssertEqual(Rookie.xpNeeded(Rookie.freeLevels), xpToNext(Rookie.freeLevels))
        let l = Loadout()
        let opts = Rookie.featureSwarm([.passive(.speed, toLevel: 1), .weapon(.zap, toLevel: 1), .weapon(.laser, toLevel: 2)], loadout: l)
        XCTAssertEqual(opts.count, 3)
        XCTAssertEqual(opts.first, .weapon(.swarm, toLevel: 1))
        let already = Rookie.featureSwarm([.weapon(.swarm, toLevel: 1), .heal, .coins(25)], loadout: l)
        XCTAssertEqual(already, [.weapon(.swarm, toLevel: 1), .heal, .coins(25)])
    }

    func testCitiesOpenWhenAllOrgansCleared() {
        var s = SaveData(); s.unlockedStage = 5
        XCTAssertEqual(s.unlockedInfection(1), 1)
        XCTAssertEqual(s.currentCity, 1)
        s.recordClear(Organ.all[0])
        // City 2 stays closed until every organ of city 1 is cleared.
        XCTAssertEqual(s.unlockedInfection(1), 1)
        XCTAssertFalse(s.canPlay(1, level: 2))
        XCTAssertEqual(s.infected(inCity: 1), Country.outbreakSize(1) * 4 / 5)
        for o in Organ.all.dropFirst() { s.recordClear(o) }
        XCTAssertEqual(s.citiesCleared, 1)
        XCTAssertEqual(s.currentCity, 2)
        XCTAssertEqual(s.infected(inCity: 1), 0)
        XCTAssertTrue(s.canPlay(3, level: 2))
        XCTAssertEqual(s.nextMission, Organ.all[0].at(infection: 2))
        s.recordClear(Organ.all[0].at(infection: 2))
        XCTAssertEqual(s.nextMission, Organ.all[1].at(infection: 2))
        // Older saves that only know clearedStages keep their progress.
        var old = SaveData(); old.clearedStages = [1, 2, 3, 4, 5]; old.unlockedStage = 5
        XCTAssertEqual(old.currentCity, 2)
    }

    func testCountriesHaveTenCities() {
        for c in Country.all { XCTAssertEqual(c.cities.count, Organ.maxInfection, c.name) }
        XCTAssertEqual(Country.find("pk").name, "Pakistan")
        XCTAssertEqual(Country.find("XX"), Country.world)
    }

    func testStoryScenesFollowProgress() {
        var before = SaveData(); before.countryCode = "PK"; before.unlockedStage = 5
        for o in Organ.all.dropLast() { before.recordClear(o) }
        var after = before; after.recordClear(Organ.all[4])
        let s = Story.afterWin(Organ.all[4], before: before, after: after)
        XCTAssertEqual(s?.id, "clear-1")
        XCTAssertTrue(s?.lines.contains { $0.text.contains("Islamabad") } ?? false)
        XCTAssertTrue(s?.lines.contains { $0.text.contains("Lahore") } ?? false)
        XCTAssertEqual(Story.mapScene(save: after)?.id, "city-2")
        XCTAssertNil(Story.intro(for: Organ.all[0].at(infection: 2), save: after))
        for sc in Story.scenes { XCTAssertFalse(sc.lines.isEmpty) }
    }

    func testInfectionLevelScalesDifficultyAndCoins() {
        let base = Organ.all[0], hot = base.at(infection: 5)
        XCTAssertGreaterThan(hot.difficulty, base.difficulty)
        XCTAssertGreaterThan(hot.coinReward, base.coinReward)
        XCTAssertEqual(Organ.endless.at(infection: 5).difficulty, Organ.endless.difficulty)
    }

    func testMutationRanksAfterMax() {
        var s = SaveData(); s.tech = ["power": 10]; s.coins = 2000
        XCTAssertEqual(s.nextCost(.power), 2000)
        XCTAssertTrue(s.buy(.power))
        XCTAssertEqual(s.level(.power), 10)
        XCTAssertEqual(s.rank(.power), 1)
        XCTAssertEqual(s.coins, 0)
        XCTAssertEqual(PlayerStats.make(save: s, loadout: Loadout()).damage, 1 + 0.05 * 10.4, accuracy: 0.0001)
        var r = SaveData(); r.tech = ["revive": 1]; r.coins = 99999
        XCTAssertNil(r.nextCost(.revive))
        XCTAssertFalse(r.buy(.revive))
    }

    func testDailyMissionsAreStableAndDistinct() {
        let a = DailyState.missions(for: "2026-11-04"), b = DailyState.missions(for: "2026-11-04")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 3)
        XCTAssertEqual(Set(a.map(\.kind)).count, 3)
    }

    func testDailyRecordAndClaim() {
        var s = SaveData()
        s.daily.missions = [Mission(id: 0, kind: .kills, target: 100, reward: 250),
                            Mission(id: 1, kind: .survive, target: 180, reward: 400),
                            Mission(id: 2, kind: .endless, target: 120, reward: 300)]
        s.daily.record(RunReport(kills: 60, seconds: 200, endless: false))
        XCTAssertEqual(s.daily.missions[0].progress, 60)
        XCTAssertTrue(s.daily.missions[1].done)
        XCTAssertEqual(s.daily.missions[2].progress, 0) // only Endless runs count
        XCTAssertNil(s.claimMission(0))
        XCTAssertEqual(s.claimMission(1), 400)
        XCTAssertNil(s.claimMission(1))
        s.daily.record(RunReport(kills: 60, seconds: 130, endless: true))
        XCTAssertTrue(s.daily.allDone)
        XCTAssertEqual(s.claimDailyBonus(), DailyState.bonusReward)
    }

    func testLoginStreak() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let d1 = Date(timeIntervalSince1970: 1_800_000_000)
        var d = DailyState()
        d.refresh(now: d1, calendar: cal)
        XCTAssertEqual(d.streak, 1)
        XCTAssertTrue(d.canClaimStreak)
        d.streakClaimedDay = d.lastLoginDay
        d.refresh(now: d1.addingTimeInterval(86_400), calendar: cal)
        XCTAssertEqual(d.streak, 2)
        XCTAssertTrue(d.canClaimStreak)
        d.refresh(now: d1.addingTimeInterval(86_400 * 4), calendar: cal)
        XCTAssertEqual(d.streak, 1) // missed days reset the streak
    }

    func testWeaponEvolutionNeedsMaxLevelAndPartner() {
        var l = Loadout()
        l.apply(.weapon(.laser, toLevel: 5))
        XCTAssertFalse(l.candidates().contains(.weapon(.laser, toLevel: evolvedLevel)))
        l.apply(.passive(.rapid, toLevel: 1))
        XCTAssertTrue(l.candidates().contains(.weapon(.laser, toLevel: evolvedLevel)))
        l.apply(.weapon(.laser, toLevel: evolvedLevel))
        XCTAssertFalse(l.candidates().contains { if case .weapon(.laser, _) = $0 { return true } else { return false } })
        XCTAssertGreaterThan(WeaponStats.laser(evolvedLevel).damage, WeaponStats.laser(5).damage)
    }

    func testEveryCityHasItsOwnMutation() {
        for c in ["PK", "US", "WORLD"] {
            XCTAssertEqual(CityMutation.forCity(1, country: c), CityMutation.none)
            let rest = (2...Organ.maxInfection).map { CityMutation.forCity($0, country: c) }
            XCTAssertEqual(Set(rest).count, rest.count, c)
            XCTAssertFalse(rest.contains(.none))
        }
        XCTAssertEqual(Organ.endless.mutation(country: "PK"), CityMutation.none)
    }

    func testTrophiesPayOnce() {
        var s = SaveData(); s.totalKills = 1_500
        XCTAssertTrue(Trophy.kills1k.done(s))
        XCTAssertEqual(s.unclaimedTrophies, 1)
        XCTAssertEqual(s.claimTrophy(.kills1k), Trophy.kills1k.reward)
        XCTAssertNil(s.claimTrophy(.kills1k))
        XCTAssertNil(s.claimTrophy(.kills10k))
        XCTAssertEqual(s.unclaimedTrophies, 0)
    }
}
