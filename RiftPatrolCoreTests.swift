import XCTest
@testable import RiftPatrolCore

final class RiftPatrolCoreTests: XCTestCase {
    func testShieldAbsorbsThenCracks() {
        var g = GhostEnemy(id: 1, maxHP: 50, shield: 20)
        let a = g.receive(damage: 10, isCritical: false)
        XCTAssertEqual(a.kind, .normal)
        XCTAssertEqual(g.shield, 10)
        let b = g.receive(damage: 10, isCritical: false)
        XCTAssertEqual(b.kind, .shieldCrack)
        XCTAssertEqual(b.popupText, "ECTO-CRACK!")
        XCTAssertEqual(g.hp, 50)
    }

    func testCritAndFinisher() {
        var g = GhostEnemy(id: 2, maxHP: 50)
        let c = g.receive(damage: 20, isCritical: true)
        XCTAssertEqual(c.kind, .critical)
        XCTAssertEqual(c.popupText, "CRIT! 40")
        XCTAssertEqual(g.hp, 10)
        let f = g.receive(damage: 50, isCritical: false)
        XCTAssertEqual(f.kind, .finisher)
        XCTAssertEqual(f.dealt, 10)
        XCTAssertEqual(f.popupText, "BANISHED! 10")
        XCTAssertEqual(f.hitStopSeconds, 0.04, accuracy: 0.0001)
        XCTAssertFalse(g.isAlive)
        XCTAssertEqual(g.receive(damage: 5, isCritical: false).dealt, 0)
    }

    func testComboWindowAndTiers() {
        var c = ComboTracker()
        c.registerKill(at: 0)
        c.registerKill(at: 3.0)
        c.registerKill(at: 6.0)
        XCTAssertEqual(c.tier, .triple)
        XCTAssertEqual(c.tier.banner, "x3 TRIPLE BANISH")
        c.registerKill(at: 9.5)
        XCTAssertEqual(c.count, 1)

        var d = ComboTracker()
        for i in 0..<6 { d.registerKill(at: Double(i)) }
        XCTAssertEqual(d.tier, .god)
        XCTAssertGreaterThan(d.pitch, 1.2)
        d.update(at: 100)
        XCTAssertEqual(d.count, 0)
        XCTAssertEqual(d.best, 6)
    }

    func testSessionScrapTurretsAndEnd() {
        var s = GameSession(finalWave: 2)
        XCTAssertFalse(s.buyTurret(.monkeyTesla))
        for i in 0..<10 { s.registerKill(at: Double(i) * 10) }
        XCTAssertEqual(s.scrap, 60)
        XCTAssertTrue(s.buyTurret(.monkeyTesla))
        XCTAssertEqual(s.scrap, 20)
        s.damageVan(200)
        XCTAssertEqual(s.status, .gameOver)
        XCTAssertEqual(s.vanHP, 0)

        var v = GameSession(finalWave: 2)
        v.completeWave()
        XCTAssertEqual(v.wave, 2)
        v.completeWave()
        XCTAssertEqual(v.status, .victory)
    }

    func testSessionDefaultsToTenLevelsAndRepairs() {
        var s = GameSession()
        XCTAssertEqual(s.finalWave, LevelCatalog.count)
        s.damageVan(50)
        s.completeWave()
        XCTAssertEqual(s.level, 2)
        XCTAssertEqual(s.vanHP, 50 + LevelCatalog.repairBetweenLevels)
        XCTAssertGreaterThan(s.scaledDamage(10), 10)
    }

    func testCatalogHasTwoLapsOfEveryCategory() {
        let all = LevelCatalog.all
        XCTAssertEqual(all.count, 10)
        for category in LevelCategory.allCases {
            XCTAssertEqual(all.filter { $0.category == category }.count, 2, "\(category)")
        }
        for i in 0..<5 {
            let first = all[i], second = all[i + 5]
            XCTAssertEqual(first.category, second.category)
            XCTAssertGreaterThan(second.hp, first.hp)
            XCTAssertGreaterThan(second.speed, first.speed)
            XCTAssertGreaterThan(second.vanDamage, first.vanDamage)
        }
        XCTAssertTrue(all[4].hasBoss)
        XCTAssertTrue(all[9].hasBoss)
        XCTAssertGreaterThan(all[9].bossHP, all[4].bossHP)
        XCTAssertTrue(all[9].isFinal)
        XCTAssertGreaterThan(all[3].zigzag, 0)
        XCTAssertEqual(LevelCatalog.spec(forLevel: 99), all[9])
    }

    func testSimIsDeterministicAndWinnable() {
        let a = BattleSim.run(seed: 42)
        XCTAssertEqual(a, BattleSim.run(seed: 42))
        XCTAssertTrue(a.won)
        XCTAssertEqual(a.wavesCleared, LevelCatalog.count)
    }

    func testFinalLevelIsHardButWinnable() {
        let reports = (1...20).map { BattleSim.run(seed: UInt64($0)) }
        let wins = reports.filter(\.won).count
        XCTAssertGreaterThan(wins, 0, "Level 10 must stay winnable")
        XCTAssertTrue(reports.allSatisfy { $0.wavesCleared >= 5 }, "Lap one should be beatable")
    }
}
