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
        var s = SaveData(); s.coins = 77; s.clearedStages = [1]; s.infectionCleared = ["1": 1]; s.tech = ["speed": 3]
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
        let old = try! JSONDecoder().decode(SaveData.self, from: Data(#"{"clearedStages": [1, 2, 3, 4, 5], "unlockedStage": 5}"#.utf8))
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

    func testCityRewardsUnlockWeaponsAndSkins() {
        var s = SaveData(); s.unlockedStage = 5
        XCTAssertEqual(s.lockedWeapons, [.freeze, .missile, .saw, .rain])
        XCTAssertFalse(Loadout().candidates().contains(.weapon(.freeze, toLevel: 1)))
        for lv in 1...2 { for o in Organ.all { s.recordClear(o.at(infection: lv)) } }
        XCTAssertEqual(s.citiesCleared, 2)
        XCTAssertEqual(s.lockedWeapons, [.missile, .saw, .rain])
        var l = Loadout(); l.locked = s.lockedWeapons
        XCTAssertTrue(l.candidates().contains(.weapon(.freeze, toLevel: 1)))
        XCTAssertFalse(s.owns(.frost))
        for o in Organ.all { s.recordClear(o.at(infection: 3)) }
        XCTAssertTrue(s.owns(.frost))
        XCTAssertGreaterThan(WeaponStats.missile(evolvedLevel).damage, WeaponStats.missile(1).damage)
    }

    func testCraftingUsesBossDNA() {
        var s = SaveData(); s.coins = 10_000
        let saw = Recipe.all.first { $0.weapon == .saw }!
        XCTAssertFalse(s.canCraft(saw))
        s.bossDNA = saw.dna
        XCTAssertTrue(s.craft(saw))
        XCTAssertEqual(s.bossDNA, 0)
        XCTAssertEqual(s.coins, 10_000 - saw.coins)
        XCTAssertFalse(s.lockedWeapons.contains(.saw))
        XCTAssertTrue(s.lockedWeapons.contains(.rain))
        XCTAssertFalse(s.craft(saw))
        XCTAssertEqual(EnemyKind.bossSumo.dnaDrop, 1)
        XCTAssertEqual(EnemyKind.bossVira.dnaDrop, 3)
        XCTAssertEqual(EnemyKind.blob.dnaDrop, 0)
        XCTAssertGreaterThan(WeaponStats.saw(5).damage, WeaponStats.saw(1).damage)
        XCTAssertGreaterThan(WeaponStats.rain(5).strikes, WeaponStats.rain(1).strikes)
        let back = try! JSONDecoder().decode(SaveData.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back.crafted, ["saw"])
    }

    func testSeasonPassTiersAndReset() {
        var s = SaveData()
        let nov = DateComponents(calendar: .current, year: 2026, month: 11, day: 4).date!
        let dec = DateComponents(calendar: .current, year: 2026, month: 12, day: 1).date!
        s.refreshSeason(now: nov)
        XCTAssertEqual(s.seasonKey, "2026-11")
        XCTAssertEqual(Season.title(s.seasonKey), "November Season")
        s.seasonXP = 520
        XCTAssertEqual(s.seasonTier, 5)
        XCTAssertEqual(s.unclaimedSeasonTiers, 5)
        let paid = s.claimSeason()
        XCTAssertEqual(paid.dna, 2)
        XCTAssertEqual(paid.coins, (1...4).reduce(0) { $0 + 100 + 10 * $1 })
        XCTAssertEqual(s.unclaimedSeasonTiers, 0)
        XCTAssertEqual(s.claimSeason().coins, 0)
        s.seasonXP = 99_999
        XCTAssertEqual(s.seasonTier, Season.tiers)
        XCTAssertEqual(Season.reward(tier: 30), .dna(8))
        s.refreshSeason(now: dec)
        XCTAssertEqual(s.seasonXP, 0); XCTAssertEqual(s.seasonClaimed, 0)
        XCTAssertGreaterThan(Season.runXP(kills: 500, bosses: 1, seconds: 240, won: true), Season.runXP(kills: 50, bosses: 0, seconds: 60, won: false))
        XCTAssertLessThanOrEqual(Season.runXP(kills: 99_999, bosses: 9, seconds: 9_999, won: true), 250)
    }

    func testOutbreakAlertIsPlayableAndPaysOnce() {
        var s = SaveData(); s.countryCode = "PK"
        for day in ["2026-11-01", "2026-11-02", "2026-11-03"] {
            let a = s.outbreakAlert(day: day)
            XCTAssertTrue(s.canPlay(a.organID, level: a.level))
        }
        XCTAssertEqual(s.outbreakAlert(day: "2026-11-01"), OutbreakAlert(organID: 1, level: 1))
        for lv in 1...3 { for o in Organ.all { s.recordClear(o.at(infection: lv)) } }
        let day = "2026-11-05"
        let a = s.outbreakAlert(day: day)
        XCTAssertEqual(a, s.outbreakAlert(day: day))
        XCTAssertTrue(s.canPlay(a.organID, level: a.level))
        let other = Organ.all[a.organID % 5].at(infection: a.level)
        XCTAssertFalse(s.claimAlert(other, alert: a, day: day))
        let coins = s.coins
        XCTAssertTrue(s.claimAlert(a.organ, alert: a, day: day))
        XCTAssertEqual(s.coins, coins + OutbreakAlert.coinBonus)
        XCTAssertEqual(s.bossDNA, OutbreakAlert.dnaBonus)
        XCTAssertFalse(s.claimAlert(a.organ, alert: a, day: day))
        XCTAssertFalse(s.claimAlert(.endless, alert: a, day: "2026-11-06"))
    }

    func testVaccineLabBoostsNextRun() {
        XCTAssertTrue(VaccineLab.hit(0.5, try: 0))
        XCTAssertFalse(VaccineLab.hit(0.95, try: 0))
        XCTAssertEqual(VaccineLab.needle(0), 0, accuracy: 0.001)
        XCTAssertEqual(VaccineLab.needle(1.25), 1, accuracy: 0.001)
        XCTAssertEqual(VaccineLab.needle(2.5), 0, accuracy: 0.001)
        var s = SaveData()
        let base = PlayerStats.make(save: s, loadout: Loadout())
        s.labBoost = 3
        let boosted = PlayerStats.make(save: s, loadout: Loadout())
        XCTAssertEqual(boosted.damage, base.damage + 3 * VaccineLab.damagePerStar, accuracy: 0.0001)
        XCTAssertEqual(boosted.maxHP, base.maxHP + 30, accuracy: 0.0001)
        let back = try! JSONDecoder().decode(SaveData.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back.labBoost, 3)
    }

    func testFirstCityKeepsClassicBosses() {
        for o in Organ.all {
            let b = o.bossSetup(country: "PK")
            XCTAssertEqual(b.kind, o.boss)
            XCTAssertEqual(b.variant, .normal)
            XCTAssertEqual(b.title, o.boss.bossTitle)
        }
        XCTAssertEqual(Organ.all[4].at(infection: 10).bossSetup(country: "PK").kind, .bossVex)
    }

    func testEachLaterCityHasFiveDifferentBossFights() {
        for country in ["PK", "US", "WORLD"] {
            var lineups = Set<[EnemyKind]>()
            for lv in 2...9 where lv != Country.villainCity {
                let setups = Organ.all.map { $0.at(infection: lv).bossSetup(country: country) }
                XCTAssertEqual(Set(setups.map(\.kind)).count, 5, "\(country) city \(lv) bosses")
                XCTAssertEqual(Set(setups.map(\.variant)).count, 5, "\(country) city \(lv) variants")
                XCTAssertFalse(setups.contains { $0.variant == .normal })
                XCTAssertTrue(setups.allSatisfy { $0.title.hasPrefix($0.variant.prefix + " ") })
                XCTAssertTrue(setups.allSatisfy { $0.texture == "\($0.kind.texture)-\($0.variant.rawValue)" })
                lineups.insert(setups.map(\.kind))
            }
            XCTAssertGreaterThan(lineups.count, 3, "\(country) cities should not all repeat one lineup")
        }
        // Same city, same lineup (a retry is fair); another country plays it differently somewhere.
        let a = Organ.all[0].at(infection: 4).bossSetup(country: "PK")
        XCTAssertEqual(a, Organ.all[0].at(infection: 4).bossSetup(country: "PK"))
        let pk = (2...9).flatMap { lv in Organ.all.map { $0.at(infection: lv).bossSetup(country: "PK") } }
        let us = (2...9).flatMap { lv in Organ.all.map { $0.at(infection: lv).bossSetup(country: "US") } }
        XCTAssertNotEqual(pk, us)
    }

    func testOrgansHaveSignatureVirusesAndCityGuests() {
        XCTAssertEqual(Organ.all.compactMap(\.signature), [.spore, .bomber, .healer, .sniper])
        for o in Organ.all {
            let first = o.extraKinds(country: "PK")
            if let sig = o.signature { XCTAssertEqual(first, [sig]) } else { XCTAssertEqual(first.count, 2) }
            let later = o.at(infection: 7).extraKinds(country: "PK")
            XCTAssertEqual(later.count, first.count + 2)
            XCTAssertEqual(Set(later).count, later.count)
            XCTAssertTrue(later.allSatisfy { EnemyKind.specials.contains($0) })
        }
        XCTAssertEqual(Set(Organ.endless.extraKinds(country: "PK")), Set(EnemyKind.specials))
        // Specials join the mix after the opening seconds.
        XCTAssertFalse(Spawner.kinds(time: 10, extra: [.sniper]).contains { $0.0 == .sniper })
        XCTAssertTrue(Spawner.kinds(time: 40, extra: [.sniper]).contains { $0.0 == .sniper })
        let p = PlayerStats.make(save: SaveData(), loadout: Loadout())
        for kind in EnemyKind.specials { XCTAssertGreaterThan(p.speed, kind.base.speed * 1.12 * 1.75, "\(kind)") }
    }

    func testCityStrainsMiniBossesAndBackdrops() {
        XCTAssertNil(VirusStrain.forCity(1, country: "PK"))
        let strains = (2...10).compactMap { VirusStrain.forCity($0, country: "PK") }
        XCTAssertEqual(Set(strains).count, 9, "every city after the first has its own strain")
        XCTAssertEqual(VirusStrain.forCity(3, country: "PK"), VirusStrain.forCity(3, country: "PK"))
        XCTAssertEqual(EnemyKind.spiky.texture(strain: .horned), "virus-spiky-horned")
        XCTAssertEqual(EnemyKind.bomber.texture(strain: .horned), "virus-bomber")
        XCTAssertEqual(EnemyKind.spiky.texture(strain: nil), "virus-spiky")
        XCTAssertNil(Organ.endless.strain(country: "PK"))
        for o in Organ.all {
            for lv in 1...10 {
                let m = o.at(infection: lv).miniBoss(country: "PK")
                XCTAssertTrue(m.isMiniBoss)
                XCTAssertFalse(m.isBoss)
                XCTAssertFalse(m.miniTitle.isEmpty)
            }
        }
        let seen = Set(Organ.all.flatMap { o in (1...10).map { o.at(infection: $0).miniBoss(country: "PK") } })
        XCTAssertEqual(seen.count, 4, "all four mini bosses show up somewhere")
        XCTAssertEqual(Organ.all[0].backdrop, "bg-lungs")
        XCTAssertEqual(Organ.all[0].at(infection: 2).backdrop, "bg-lungs-2")
        XCTAssertEqual(Organ.endless.backdrop, "bg-endless")
    }

    func testVaccineReportAfterEveryOrganClear() {
        // City 2, second organ cleared: Dr. Leuko reports vaccine progress.
        var before = SaveData(); before.countryCode = "PK"; before.unlockedStage = 5
        for o in Organ.all { before.recordClear(o) }
        before.recordClear(Organ.all[0].at(infection: 2))
        var after = before; after.recordClear(Organ.all[1].at(infection: 2))
        let s = Story.afterWin(Organ.all[1].at(infection: 2), before: before, after: after)
        XCTAssertEqual(s?.id, "vaccine-2-2")
        XCTAssertTrue(s?.title.contains("2/5") ?? false)
        XCTAssertTrue(s?.lines.contains { $0.text.contains("Lahore") && $0.text.contains("Vaccine 2 of 5") } ?? false)
        // Replaying an organ already cleared at that level says nothing.
        XCTAssertNil(Story.afterWin(Organ.all[1].at(infection: 2), before: after, after: after))
        // Last organ of the city: the vaccine is ready and the city is saved.
        var b2 = after
        for o in Organ.all[2...3] { b2.recordClear(o.at(infection: 2)) }
        var a2 = b2; a2.recordClear(Organ.all[4].at(infection: 2))
        let saved = Story.afterWin(Organ.all[4].at(infection: 2), before: b2, after: a2)
        XCTAssertEqual(saved?.title, "Lahore Saved!")
        XCTAssertTrue(saved?.lines.contains { $0.text.contains("vaccine is ready") } ?? false)
        // First city: the chapter outro also carries the vaccine progress.
        var f0 = SaveData(); f0.countryCode = "PK"
        var f1 = f0; f1.recordClear(Organ.all[0])
        let first = Story.afterWin(Organ.all[0], before: f0, after: f1)
        XCTAssertEqual(first?.id, "outro-1")
        XCTAssertTrue(first?.lines.contains { $0.text.contains("Vaccine 1 of 5") } ?? false)
    }

    func testPediaCoversEveryCharacterOnce() {
        XCTAssertEqual(Pedia.all.count, 103)
        XCTAssertTrue(Pedia.ids.contains("villain-vira"))
        XCTAssertEqual(Pedia.ids.count, Pedia.all.count, "card ids are unique")
        XCTAssertTrue(Pedia.ids.contains("virus-spiky-horned"))
        XCTAssertTrue(Pedia.ids.contains("boss-sumo-frost"))
        XCTAssertTrue(Pedia.ids.contains("miniboss-magnet"))
        XCTAssertTrue(Pedia.ids.contains("king-vex"))
        XCTAssertTrue(Pedia.all.allSatisfy { !$0.name.isEmpty && !$0.line.isEmpty })
        // Every boss a city can throw at you has a card.
        for lv in 1...10 { for o in Organ.all { XCTAssertNotNil(Pedia.entry(o.at(infection: lv).bossSetup(country: "PK").texture)) } }
    }

    func testAlliesRecruitAndPick() {
        var s = SaveData()
        XCTAssertNil(s.ally)
        XCTAssertFalse(s.ownsAlly(.medic))
        XCTAssertFalse(s.recruitAlly(.medic), "the Medic joins only after a city is saved")
        s.coins = 3_000
        XCTAssertTrue(s.recruitAlly(.guardian))
        XCTAssertEqual(s.coins, 500)
        XCTAssertEqual(s.ally, .guardian)
        XCTAssertFalse(s.recruitAlly(.hunter))
        for o in Organ.all { s.recordClear(o) }
        XCTAssertTrue(s.ownsAlly(.medic))
        XCTAssertTrue(s.recruitAlly(.medic))
        XCTAssertEqual(s.coins, 500, "picking an owned ally is free")
        XCTAssertEqual(s.ally, .medic)
    }

    func testSpecialMissionsPerCity() {
        for o in Organ.all { XCTAssertEqual(o.mode(country: "PK"), .normal, "city 1 is classic") }
        for lv in 2...9 {
            let modes = Organ.all.map { $0.at(infection: lv).mode(country: "PK") }
            XCTAssertLessThanOrEqual(modes.filter { $0 == .defense }.count, 1, "city \(lv)")
            XCTAssertLessThanOrEqual(modes.filter { $0 == .escape }.count, lv >= 3 ? 1 : 0, "city \(lv)")
            XCTAssertGreaterThanOrEqual(modes.filter { $0 != .normal }.count, lv >= 3 ? 1 : 0)
        }
        XCTAssertEqual(Organ.all[4].at(infection: Country.villainCity).mode(country: "PK"), .normal, "the villain fight is a normal run")
        XCTAssertEqual(Organ.all[4].at(infection: 10).mode(country: "PK"), .normal, "King Vex's fight stays a normal run")
        XCTAssertEqual(Organ.endless.mode(country: "PK"), .normal)
        XCTAssertEqual(Organ.bossRush.mode(country: "PK"), .normal)
    }

    func testBossRushIsWeeklyAndNeverCountsTowardCities() {
        let a = BossRush.lineup(week: "2026-W45"), b = BossRush.lineup(week: "2026-W46")
        XCTAssertEqual(a.count, BossRush.bosses)
        XCTAssertEqual(Set(a.map(\.kind)).count, 5)
        XCTAssertEqual(a, BossRush.lineup(week: "2026-W45"))
        XCTAssertNotEqual(a, b)
        XCTAssertFalse(a.contains { $0.variant == .normal })
        var s = SaveData(); s.recordClear(.bossRush)
        XCTAssertTrue(s.clearedStages.isEmpty)
        XCTAssertEqual(Organ.bossRush.coinReward, 0)
        XCTAssertNil(Story.afterWin(.bossRush, before: SaveData(), after: s))
        XCTAssertFalse(SaveData().bossRushUnlocked)
        let d = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(identifier: "UTC"), year: 2026, month: 11, day: 4, hour: 12).date!
        XCTAssertEqual(BossRush.week(d), "2026-W45")
    }

    func testComboRewardsAndOldSavesDecode() throws {
        XCTAssertNil(Combo.reward(at: 24))
        XCTAssertEqual(Combo.reward(at: 25), 5)
        XCTAssertEqual(Combo.reward(at: 400), 80)
        let old = try JSONDecoder().decode(SaveData.self, from: Data(#"{"coins": 42}"#.utf8))
        XCTAssertEqual(old.coins, 42)
        XCTAssertTrue(old.discovered.isEmpty)
        XCTAssertNil(old.allyID)
        XCTAssertEqual(old.bestCombo, 0)
    }

    func testEachCountryIsItsOwnCampaign() {
        var s = SaveData()
        s.switchCountry(to: "PK")
        for o in Organ.all { s.recordClear(o) }
        XCTAssertEqual(s.citiesCleared, 1)
        s.switchCountry(to: "IN")
        XCTAssertEqual(s.citiesCleared, 0, "New Delhi is not saved just because Islamabad was")
        XCTAssertEqual(s.currentCity, 1)
        XCTAssertTrue(s.canPlay(1, level: 1))
        XCTAssertFalse(s.canPlay(2, level: 1), "each campaign starts from the Lungs")
        XCTAssertEqual(s.bestCities, 1, "unlocks earned in Pakistan stay")
        XCTAssertTrue(s.ownsAlly(.medic))
        XCTAssertEqual(s.citiesSaved(in: "PK"), 1)
        XCTAssertEqual(s.citiesSavedEverywhere, 1)
        s.recordClear(Organ.all[0])
        s.switchCountry(to: "PK")
        XCTAssertEqual(s.citiesCleared, 1, "Pakistan progress comes back")
        XCTAssertEqual(s.citiesSaved(in: "IN"), 0)
        XCTAssertEqual(s.countryProgress["IN"]?["1"], 1)
        // The first country pick keeps what a player did before choosing.
        var fresh = SaveData(); fresh.recordClear(Organ.all[0])
        fresh.switchCountry(to: "GB")
        XCTAssertEqual(fresh.clearedInfection(1), 1)
    }

    func testContinentVillainsRuleTheFifthCity() {
        XCTAssertEqual(Country.find("PK").villain, .bossVira)
        XCTAssertEqual(Country.find("SA").villain, .bossSultan)
        XCTAssertEqual(Country.find("GB").villain, .bossBaron)
        XCTAssertEqual(Country.find("US").villain, .bossGeneral)
        for c in Country.all {
            let b = Organ.all[4].at(infection: Country.villainCity).bossSetup(country: c.id)
            XCTAssertEqual(b.kind, c.villain, c.name)
            XCTAssertTrue(b.kind.isBoss && b.kind.isVillain)
        }
        XCTAssertEqual(Organ.all[4].at(infection: 10).bossSetup(country: "PK").kind, .bossVex)
        var s = SaveData(); s.countryCode = "IN"
        for lv in 1...4 { for o in Organ.all { s.recordClear(o.at(infection: lv)) } }
        XCTAssertTrue(Story.mapScene(save: s)?.lines.contains { $0.text.contains("Queen Vira") } ?? false)
    }
}
