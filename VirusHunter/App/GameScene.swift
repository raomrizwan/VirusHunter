import SpriteKit
import UIKit

// MARK: - Entities

final class Enemy {
    let kind: EnemyKind
    let node: SKSpriteNode
    var pos: CGPoint
    var hp: Double
    let maxHP: Double
    var speed: Double
    let radius: Double
    let damage: Double
    let xp: Int
    var knock = CGVector.zero
    var flash: Double = 0
    var timerA: Double = 0     // ability timer (dash / shoot / boss attack)
    var timerB: Double = 0
    var dashing: Double = 0
    var dashDir = CGVector.zero
    var timerC: Double = 0
    var spin: Double = 0       // rotating aim for spiral attacks
    var phase = 0              // boss phase (King Vex enrages at half health)
    var golden = false         // Golden Virus event: flees, drops lots of coins
    var slowT: Double = 0      // Freeze Ray chill
    var slowAmt: Double = 0
    var shieldHitCD: Double = 0
    var fieldHitCD: Double = 0
    var variant: BossVariant = .normal
    var title: String = ""
    var variantT: Double = 4   // boss variant ability timer
    var summoned = false       // Mega boss already called for backup
    var cloaked = false        // Shadow boss is invisible right now
    var aux: SKNode?           // extra visual (sniper aim line)
    /// Resting tint (boss variant, Golden Virus, enraged Vex); hit flashes return to it.
    var baseTint: UIColor = .white
    var baseBlend: CGFloat = 0
    var alive = true
    /// Idle wiggle, animated in `render()` rather than with per-node SKActions (hundreds of those add up).
    var wobblePhase = 0.0
    var wobbleAngle: CGFloat = 0
    var isElite: Bool { kind == .elite }

    init(kind: EnemyKind, node: SKSpriteNode, pos: CGPoint, hp: Double, speed: Double, radius: Double, damage: Double, xp: Int) {
        self.kind = kind; self.node = node; self.pos = pos; self.hp = hp; self.maxHP = hp
        self.speed = speed; self.radius = radius; self.damage = damage; self.xp = xp
    }
}

private struct Bolt { var pos: CGPoint; var vel: CGVector; var damage: Double; var pierce: Int; var life: Double; let node: SKSpriteNode; var hit: Set<ObjectIdentifier> = []
    var blast: Double = 0      // > 0: homing missile that explodes on hit
}
private struct Shot { var pos: CGPoint; var vel: CGVector; var damage: Double; var life: Double; let node: SKSpriteNode
    var chill = false          // Frost boss: slows Nano on hit
}
private struct Bomb { var pos: CGPoint; var fuse: Double; let node: SKSpriteNode }
private struct Puddle { var pos: CGPoint; var life: Double; var armed: Double; let node: SKShapeNode; var radius: Double = 70 }
private enum PickupKind { case xp(Int), coin(Int), heart, chest }
private struct Pickup { let kind: PickupKind; var pos: CGPoint; let node: SKSpriteNode; var pulled = false }
private final class Bot {
    let node: SKSpriteNode
    var angle: Double
    var pos = CGPoint.zero
    weak var target: Enemy?
    var cooldown: Double = 0
    var returning = false
    init(node: SKSpriteNode, angle: Double) { self.node = node; self.angle = angle }
}

// MARK: - Vector helpers

@inline(__always) private func len(_ v: CGVector) -> Double { Double(sqrt(v.dx * v.dx + v.dy * v.dy)) }
@inline(__always) private func sub(_ a: CGPoint, _ b: CGPoint) -> CGVector { CGVector(dx: a.x - b.x, dy: a.y - b.y) }
@inline(__always) private func dist2(_ a: CGPoint, _ b: CGPoint) -> Double { let dx = Double(a.x - b.x), dy = Double(a.y - b.y); return dx * dx + dy * dy }
@inline(__always) private func norm(_ v: CGVector) -> CGVector { let l = len(v); return l < 0.0001 ? .zero : CGVector(dx: v.dx / l, dy: v.dy / l) }

// MARK: - Scene

final class GameScene: SKScene {
    let state: RunState
    private var save: SaveData
    private let autoplay: Bool
    private let god: Bool
    private let bossNear = ProcessInfo.processInfo.arguments.contains("-bossNear")
    private var rng = SystemRandomNumberGenerator()

    // world
    private let world = SKNode()
    private let cam = SKCameraNode()
    private var bgTiles: [SKSpriteNode] = []
    private let tile: CGFloat = 512
    private let enemyLayer = SKNode(), fxLayer = SKNode(), pickupLayer = SKNode(), shotLayer = SKNode()

    // player
    private let player = SKSpriteNode()
    private let skin: Skin
    private let playerShadow = SKShapeNode(ellipseOf: CGSize(width: 44, height: 12))
    private let hpBar = SKShapeNode(rectOf: CGSize(width: 46, height: 6), cornerRadius: 3)
    private let hpFill = SKSpriteNode(color: UIColor(red: 0.3, green: 0.95, blue: 0.55, alpha: 1), size: CGSize(width: 44, height: 4))
    private var ppos = CGPoint.zero
    private var hp: Double = 100
    private var stats: PlayerStats
    private var invuln: Double = 0
    private var moveDir = CGVector.zero
    private let playerRadius: Double = 17

    // joystick
    private let joyBase = SKShapeNode(circleOfRadius: 52)
    private let joyKnob = SKShapeNode(circleOfRadius: 24)
    private var joyOrigin: CGPoint?

    // run
    private var enemies: [Enemy] = []
    private var bolts: [Bolt] = []
    private var shots: [Shot] = []
    private var bombs: [Bomb] = []
    private var pickups: [Pickup] = []
    private var bots: [Bot] = []
    private var shieldNodes: [SKSpriteNode] = []
    private var shieldAngle: Double = 0
    private let fieldNode = SKShapeNode(circleOfRadius: 70)
    private var grid: [Int: [Enemy]] = [:]
    private let cell: Double = 72

    private var time: Double = 0
    private var lastUpdate: TimeInterval = 0
    private var spawnAcc: Double = 0
    private var xp = 0
    private var level = 1
    private var pendingLevels = 0
    private var kills = 0
    private var coinsCollected = 0
    private var laserT = 0.0, zapT = 0.0, bombT = 0.0, fieldT = 0.0, freezeT = 0.0, missileT = 0.0
    private var nextElite: Double = 60
    private var nextBoss: Double
    private var bossCount = 0
    private var bossKills = 0
    /// This city's twist (see `CityMutation`).
    private let mutation: CityMutation
    private var puddles: [Puddle] = []
    private var nextPuddle = 3.0
    /// This run's boss and its variant, and the special viruses joining the mix.
    private let bossSetup: BossSetup
    private let extraKinds: [EnemyKind]
    /// Enemy whose attack is firing right now (boss variants color and chill its shots).
    private weak var shooter: Enemy?
    private var chilled = 0.0          // Frost shots slow Nano
    private var darkness: SKSpriteNode?
    // Random events
    private var nextGolden = Double.random(in: 55...95)
    private var nextSupply = Double.random(in: 70...110)
    private var ambushAt = Double.random(in: 100...190)
    private var ambushEnds: Double?
    private var goldenKills = 0
    // Organ hazards (each stage has its own danger)
    private var nextHazard = 18.0
    private var wind = CGVector.zero
    private var windLeft = 0.0
    private var rush = 0.0                 // Heart: viruses sprint during a heartbeat
    // Bonus objective
    private enum Objective { case noHit, kills, fastBoss, chests }
    private var objective: Objective?
    private var lastHit = 0.0
    private var bossSpawnedAt: Double?
    private var chestsOpened = 0
    private var objectiveDone = false
    private weak var boss: Enemy?
    private var bossDefeated = false
    private var simPaused = false
    private var over = false
    private var shake: Double = 0
    private var hudTimer: Double = 0
    private var textures: [String: SKTexture] = [:]
    /// First run ever: faster early levels, a damage boost and Nano Swarm offered first (see `Rookie`).
    private let rookie: Bool
    private var swarmFeatured = false
    private var labelPool: [SKLabelNode] = []

    init(size: CGSize, state: RunState, save: SaveData, autoplay: Bool = false, god: Bool = false) {
        self.state = state
        self.save = save
        self.autoplay = autoplay
        self.god = god
        self.skin = save.skin
        let rookie = save.runs == 0 && !state.organ.isEndless
        self.rookie = rookie
        var stats = PlayerStats.make(save: save, loadout: state.loadout)
        if rookie { stats.damage *= Rookie.damageBoost }
        self.stats = stats
        self.nextBoss = state.organ.bossTime
        let mutation = state.organ.mutation(country: save.country.id)
        self.mutation = mutation
        self.bossSetup = state.organ.bossSetup(country: save.country.id)
        self.extraKinds = state.organ.extraKinds(country: save.country.id)
        self.nextElite = mutation.eliteInterval ?? state.organ.eliteInterval
        super.init(size: size)
        hp = stats.maxHP
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(red: 0.03, green: 0.04, blue: 0.08, alpha: 1)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func tex(_ name: String) -> SKTexture {
        if let t = textures[name] { return t }
        let t = SKTexture(imageNamed: name); textures[name] = t; return t
    }

    // MARK: setup

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        addChild(world)
        camera = cam
        addChild(cam)
        let bg = tex("bg-\(state.organ.key)")
        for _ in 0..<9 {
            let s = SKSpriteNode(texture: bg, size: CGSize(width: tile, height: tile))
            s.alpha = 0.5; s.zPosition = -100
            world.addChild(s); bgTiles.append(s)
        }
        for (l, z) in [(pickupLayer, 1.0), (enemyLayer, 2.0), (shotLayer, 4.0), (fxLayer, 6.0)] { l.zPosition = CGFloat(z); world.addChild(l) }

        fieldNode.strokeColor = UIColor(red: 0.45, green: 0.95, blue: 1, alpha: 0.55)
        fieldNode.fillColor = UIColor(red: 0.25, green: 0.85, blue: 1, alpha: 0.10)
        fieldNode.lineWidth = 4; fieldNode.blendMode = .add; fieldNode.isHidden = true; fieldNode.zPosition = 3
        world.addChild(fieldNode)

        playerShadow.fillColor = UIColor(white: 0, alpha: 0.35); playerShadow.strokeColor = .clear; playerShadow.zPosition = 4.5
        world.addChild(playerShadow)
        player.texture = tex(skin.texture(.fight))
        player.size = CGSize(width: 58, height: 58); player.zPosition = 5
        world.addChild(player)
        hpBar.fillColor = UIColor(white: 0, alpha: 0.55); hpBar.strokeColor = .clear; hpBar.zPosition = 5.5
        hpFill.anchorPoint = CGPoint(x: 0, y: 0.5); hpFill.position = CGPoint(x: -22, y: 0)
        hpBar.addChild(hpFill)
        world.addChild(hpBar)
        player.run(.repeatForever(.sequence([.moveBy(x: 0, y: 3, duration: 0.5), .moveBy(x: 0, y: -3, duration: 0.5)])))

        for n in [joyBase, joyKnob] {
            n.strokeColor = UIColor(white: 1, alpha: 0.35); n.lineWidth = 2; n.alpha = 0; n.zPosition = 100
            cam.addChild(n)
        }
        joyBase.fillColor = UIColor(white: 1, alpha: 0.06)
        joyKnob.fillColor = UIColor(red: 0.45, green: 0.95, blue: 1, alpha: 0.45)

        state.loadout.locked = save.lockedWeapons
        state.onChoose = { [weak self] o in self?.choose(o) }
        state.onResume = { [weak self] in self?.simPaused = false; self?.state.phase = .playing }
        state.onRevive = { [weak self] in self?.revive() }
        rebuildWeapons()
        // A few starting viruses so the screen is never empty.
        for _ in 0..<6 { spawn(.spiky) }
        setupDarkness()
        pickObjective()
        if mutation != .none { state.flash("\(mutation.title.uppercased())!", seconds: 3) }
        state.moveHint = rookie && !autoplay
        pushHUD()
    }

    // MARK: input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: cam)
        state.moveHint = false
        joyOrigin = p
        joyBase.position = p; joyKnob.position = p
        joyBase.run(.fadeAlpha(to: 1, duration: 0.1)); joyKnob.run(.fadeAlpha(to: 1, duration: 0.1))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, var o = joyOrigin else { return }
        let p = t.location(in: cam)
        var v = sub(p, o)
        var l = len(v)
        let maxR = 52.0
        if l > maxR {
            // Drag the base along behind the thumb, so leaving the circle keeps full speed in the thumb's direction.
            let k = (l - maxR) / l
            o = CGPoint(x: o.x + v.dx * k, y: o.y + v.dy * k)
            joyOrigin = o; joyBase.position = o
            v = sub(p, o); l = maxR
        }
        joyKnob.position = p
        let mag = min(1, l / 24) // full speed after a short drag
        moveDir = l < 4 ? .zero : CGVector(dx: v.dx / l * mag, dy: v.dy / l * mag)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { endTouch() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { endTouch() }
    private func endTouch() {
        joyOrigin = nil; moveDir = .zero
        joyBase.run(.fadeAlpha(to: 0, duration: 0.15)); joyKnob.run(.fadeAlpha(to: 0, duration: 0.15))
    }

    func pauseRun() {
        guard state.phase == .playing else { return }
        simPaused = true
        state.phase = .paused
    }

    // MARK: loop

    override func update(_ currentTime: TimeInterval) {
        let rawDt = lastUpdate == 0 ? 1.0 / 60 : currentTime - lastUpdate
        lastUpdate = currentTime
        guard !simPaused, !over else { return }
        // Sub-step long frames so a slow device runs at real speed instead of in slow motion.
        // Capped at two steps so a heavy frame can't snowball into ever heavier ones.
        var remaining = min(rawDt, 1.0 / 15)
        while remaining > 0.0001, !simPaused, !over {
            let dt = min(remaining, 1.0 / 30)
            remaining -= dt
            time += dt
            step(dt)
        }
        render()
        hudTimer -= rawDt
        if hudTimer <= 0 { hudTimer = 0.1; pushHUD() }
    }

    private func step(_ dt: Double) {
        if autoplay { moveDir = autoDirection() }
        // player
        var sp = stats.speed
        if chilled > 0 {
            chilled -= dt; sp *= 0.6
            player.color = UIColor(red: 0.55, green: 0.85, blue: 1, alpha: 1)
            player.colorBlendFactor = chilled > 0 ? 0.55 : 0
        }
        ppos.x += (moveDir.dx * sp + wind.dx) * dt
        ppos.y += (moveDir.dy * sp + wind.dy) * dt
        if abs(moveDir.dx) > 0.1 { player.xScale = moveDir.dx < 0 ? -1 : 1 }
        hp = min(stats.maxHP, hp + stats.regen * dt)
        invuln = max(0, invuln - dt)

        rebuildGrid()
        spawning(dt)
        moveEnemies(dt)
        weapons(dt)
        moveBolts(dt)
        moveShots(dt)
        updateBombs(dt)
        updatePickups(dt)
        updatePuddles(dt)
        updateHazards(dt)
        updateObjective()
        contactDamage()
        compact()
    }

    // MARK: spawning

    private func spawning(_ dt: Double) {
        let organ = state.organ
        if !bossDefeated {
            var rate = Spawner.rate(time: time, organ: organ)
            if boss != nil { rate *= 0.5 }
            rate *= mutation.spawnScale
            spawnAcc += rate * dt
            while spawnAcc >= 1, enemies.count < 260 {
                spawnAcc -= 1
                let k = Spawner.pick(time: time, extra: extraKinds, rng: &rng)
                if k == .mini { for _ in 0..<Int.random(in: 3...5) { spawn(.mini, near: true) } }
                else if k == .spore { groupPoint = nil; for _ in 0..<Int.random(in: 4...6) { spawn(.spore, near: true) } }
                else { spawn(k) }
            }
            if spawnAcc > 3 { spawnAcc = 3 }
        }
        if time >= nextElite && !bossDefeated {
            nextElite += eliteInterval
            spawn(.elite)
        }
        if time >= nextBoss && boss == nil && !bossDefeated {
            spawnBoss()
        }
        events()
    }

    private var groupPoint: CGPoint?
    private func spawnPoint() -> CGPoint {
        let r = Double(max(size.width, size.height)) * 0.62 + 40
        let a = Double.random(in: 0..<(2 * .pi))
        return CGPoint(x: ppos.x + cos(a) * r, y: ppos.y + sin(a) * r)
    }

    @discardableResult
    private func spawn(_ kind: EnemyKind, near: Bool = false, at: CGPoint? = nil, hpMul: Double = 1, sizeMul: Double = 1) -> Enemy {
        var p = at ?? spawnPoint()
        if near, at == nil {
            if groupPoint == nil || Double.random(in: 0..<1) < 0.25 { groupPoint = spawnPoint() }
            p = CGPoint(x: groupPoint!.x + CGFloat.random(in: -40...40), y: groupPoint!.y + CGFloat.random(in: -40...40))
        }
        let b = kind.base
        let diff = state.organ.difficulty
        let hpScale = (kind.isBoss ? diff * (1 + 0.5 * Double(bossCount)) : Spawner.healthScale(time: time) * diff * mutation.healthScale) * hpMul
        let node = SKSpriteNode(texture: tex(kind.texture))
        let radius = (kind.isBoss ? b.radius : b.radius * mutation.sizeScale) * sizeMul
        let s = radius * kind.spriteScale
        node.size = CGSize(width: s, height: s)
        node.position = p
        enemyLayer.addChild(node)
        let speedJitter = (kind.isBoss ? 1 : Double.random(in: 0.9...1.12) * mutation.speedScale) * state.organ.speedScale
        let e = Enemy(kind: kind, node: node, pos: p, hp: b.hp * hpScale, speed: b.speed * speedJitter, radius: radius,
                      damage: b.damage * (0.85 + 0.15 * diff), xp: kind.isBoss ? b.xp : b.xp * mutation.xpScale)
        e.timerA = Double.random(in: 1.5...3)
        e.wobblePhase = Double.random(in: 0..<(2 * .pi))
        e.wobbleAngle = kind == .dart ? 0 : CGFloat.random(in: 0.08...0.16)
        e.title = kind.bossTitle
        enemies.append(e)
        return e
    }

    private func spawnBoss() {
        let kinds = EnemyKind.bossRoster
        var setup = bossSetup
        if state.organ.isEndless {
            // Endless: the classic five first, then random variants.
            setup = BossSetup(kind: kinds[bossCount % kinds.count],
                              variant: bossCount < kinds.count ? .normal : BossVariant.twists.randomElement() ?? .normal)
        }
        let kind = setup.kind, v = setup.variant
        let a = Double.random(in: 0..<(2 * .pi))
        let p = bossNear ? CGPoint(x: ppos.x, y: ppos.y + 175) : CGPoint(x: ppos.x + cos(a) * 320, y: ppos.y + sin(a) * 320)
        let e = spawn(kind, at: p, hpMul: v.hpScale, sizeMul: v.sizeScale)
        e.variant = v; e.title = setup.title; e.speed *= v.speedScale
        e.node.texture = tex(setup.texture)
        if let t = v.tint {
            // The variant art already has its colors; the tint colors its shots and returns after hit flashes.
            e.baseTint = UIColor(red: t.r, green: t.g, blue: t.b, alpha: 1); e.baseBlend = 0
            restoreTint(e)
        }
        e.node.run(.repeatForever(.sequence([.scale(to: 1.04, duration: 0.6), .scale(to: 0.97, duration: 0.6)])))
        e.timerA = 3; e.timerB = 5
        boss = e
        bossCount += 1
        if bossSpawnedAt == nil { bossSpawnedAt = time }
        Sound.warning.play()
        Haptics.medium()
        shake = 0.5
        state.flash("⚠️ \(setup.title.uppercased()) INCOMING", seconds: 2.5)
        if state.organ.isEndless { nextBoss = time + state.organ.bossTime }
        if mutation == .twinBoss, !state.organ.isEndless {
            // Second boss of another kind on the other side of Nano.
            let twin: EnemyKind = kinds.first { $0 != kind && $0 != .bossMarrow } ?? .bossCowboy
            let t = spawn(twin, at: CGPoint(x: ppos.x - (p.x - ppos.x), y: ppos.y - (p.y - ppos.y)))
            t.timerA = 4; t.timerB = 6
            state.flash("⚠️ TWIN BOSSES INCOMING", seconds: 2.5)
        }
    }

    // MARK: spatial grid

    @inline(__always) private func key(_ x: Double, _ y: Double) -> Int {
        let ix = Int(floor(x / cell)) & 0xFFFF, iy = Int(floor(y / cell)) & 0xFFFF
        return ix << 16 | iy
    }

    private func rebuildGrid() {
        grid.removeAll(keepingCapacity: true)
        for e in enemies where e.alive { grid[key(Double(e.pos.x), Double(e.pos.y)), default: []].append(e) }
    }

    private func each(near p: CGPoint, radius r: Double, _ body: (Enemy) -> Void) {
        let x0 = Int(floor((Double(p.x) - r) / cell)), x1 = Int(floor((Double(p.x) + r) / cell))
        let y0 = Int(floor((Double(p.y) - r) / cell)), y1 = Int(floor((Double(p.y) + r) / cell))
        for ix in x0...x1 { for iy in y0...y1 {
            guard let list = grid[(ix & 0xFFFF) << 16 | (iy & 0xFFFF)] else { continue }
            for e in list where e.alive { body(e) }
        } }
    }

    private func nearest(to p: CGPoint, within r: Double, excluding: Set<ObjectIdentifier> = []) -> Enemy? {
        var best: Enemy?; var bd = r * r
        each(near: p, radius: r) { e in
            if excluding.contains(ObjectIdentifier(e)) { return }
            let d = dist2(e.pos, p)
            if d < bd { bd = d; best = e }
        }
        return best
    }

    // MARK: enemies

    private func moveEnemies(_ dt: Double) {
        for e in enemies where e.alive {
            var toP = sub(ppos, e.pos)
            let d = len(toP)
            toP = d > 0 ? CGVector(dx: toP.dx / d, dy: toP.dy / d) : .zero
            var v = CGVector(dx: toP.dx * e.speed, dy: toP.dy * e.speed)
            if e.golden {
                // Runs away a little slower than Nano, and escapes after 15 s.
                e.timerC -= dt
                if e.timerC <= 0 { e.alive = false; e.node.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()])); state.flash("The Golden Virus escaped..."); continue }
                v = CGVector(dx: -toP.dx * stats.speed * 0.82, dy: -toP.dy * stats.speed * 0.82)
            } else {
            switch e.kind {
            case .dart:
                e.timerA -= dt
                if e.dashing > 0 {
                    e.dashing -= dt
                    v = CGVector(dx: e.dashDir.dx * 330, dy: e.dashDir.dy * 330)
                } else if e.timerA <= 0, d < 360 {
                    e.timerA = 2.6; e.dashing = 0.45; e.dashDir = toP
                    e.node.run(.sequence([.scale(to: 1.3, duration: 0.08), .scale(to: 1, duration: 0.2)]))
                } else if e.timerA < 0.5 { v = .zero } // wind-up pause
            case .spitter:
                if d < 230 { v = CGVector(dx: -toP.dx * e.speed * 0.6, dy: -toP.dy * e.speed * 0.6) }
                e.timerA -= dt
                if e.timerA <= 0, d < 420 { e.timerA = 2.6; fire(from: e.pos, dir: toP, speed: 190, damage: 8) }
            case .bomber:
                // Runs up to Nano, stops, flashes red for 0.8 s, then explodes (hurting viruses too).
                if e.phase == 1 {
                    v = .zero
                    e.timerB -= dt
                    if e.timerB <= 0 { bomberBlast(e); continue }
                } else if d < 72 {
                    e.phase = 1; e.timerB = 0.8
                    e.baseTint = UIColor(red: 1, green: 0.2, blue: 0.15, alpha: 1); e.baseBlend = 0.65; restoreTint(e)
                    Sound.warning.play(volume: 0.25, minGap: 0.3)
                }
            case .healer:
                // Keeps its distance and heals the viruses around it.
                if d < 190 { v = CGVector(dx: -toP.dx * e.speed, dy: -toP.dy * e.speed) }
                else if d < 270 { v = CGVector(dx: -toP.dy * e.speed * 0.6, dy: toP.dx * e.speed * 0.6) }
                e.timerA -= dt
                if e.timerA <= 0 { e.timerA = 3; healAround(e) }
            case .sniper:
                // Holds back, shows a red aim line, then fires one very fast shot along it.
                e.timerA -= dt
                if e.phase == 1 {
                    v = .zero
                    e.timerB -= dt
                    e.aux?.position = e.pos
                    if e.timerB <= 0 {
                        e.phase = 0; e.timerA = 3.4
                        e.aux?.removeFromParent(); e.aux = nil
                        fire(from: e.pos, dir: e.dashDir, speed: 560, damage: 12, tint: UIColor(red: 1, green: 0.25, blue: 0.3, alpha: 1))
                    }
                } else {
                    if d < 290 { v = CGVector(dx: -toP.dx * e.speed, dy: -toP.dy * e.speed) } else if d < 380 { v = .zero }
                    if e.timerA <= 0, d < 560 {
                        e.phase = 1; e.timerB = 0.9; e.dashDir = toP
                        let path = CGMutablePath(); path.move(to: .zero); path.addLine(to: CGPoint(x: toP.dx * 700, y: toP.dy * 700))
                        let l = SKShapeNode(path: path)
                        l.strokeColor = UIColor(red: 1, green: 0.25, blue: 0.3, alpha: 0.8); l.lineWidth = 2; l.position = e.pos; l.zPosition = 3
                        l.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.1), .fadeAlpha(to: 1, duration: 0.1)])))
                        fxLayer.addChild(l); e.aux = l
                    }
                }
            case .spore:
                // Drifts in weaving clusters.
                let w = sin(time * 3 + e.wobblePhase) * 0.9
                v = CGVector(dx: (toP.dx - toP.dy * w) * e.speed, dy: (toP.dy + toP.dx * w) * e.speed)
            case .bossSumo, .bossCowboy, .bossRoyal, .bossBrain, .bossMarrow, .bossVex:
                shooter = e
                v = bossAI(e, toP: toP, d: d, dt: dt)
                variantAbility(e, dt: dt)
                shooter = nil
            default: break
            }
            }
            // separation from neighbours
            var push = CGVector.zero
            each(near: e.pos, radius: e.radius + 26) { o in
                if o === e { return }
                let dv = sub(e.pos, o.pos)
                let dd = len(dv); let min = e.radius + o.radius
                if dd < min, dd > 0.01 { let f = (min - dd) / min; push.dx += dv.dx / dd * f * 90; push.dy += dv.dy / dd * f * 90 }
            }
            if e.kind.isBoss { push = CGVector(dx: push.dx * 0.1, dy: push.dy * 0.1) }
            if rush > 0, !e.kind.isBoss { v = CGVector(dx: v.dx * 1.8, dy: v.dy * 1.8) }
            if e.slowT > 0 {
                e.slowT -= dt
                let k = 1 - e.slowAmt * (e.kind.isBoss ? 0.5 : 1)
                v = CGVector(dx: v.dx * k, dy: v.dy * k)
                if e.slowT <= 0 { restoreTint(e) }
            }
            e.pos.x += (v.dx + push.dx + e.knock.dx + wind.dx * 0.6) * dt
            e.pos.y += (v.dy + push.dy + e.knock.dy + wind.dy * 0.6) * dt
            e.knock = CGVector(dx: e.knock.dx * 0.86, dy: e.knock.dy * 0.86)
            e.shieldHitCD -= dt; e.fieldHitCD -= dt
            if e.flash > 0 {
                e.flash -= dt
                if e.flash > 0 { e.node.colorBlendFactor = 0.85 } else { restoreTint(e) }
            }
            // Keep pressure: viruses left far behind come back around.
            if d > Double(max(size.width, size.height)) * 1.3, !e.kind.isBoss, !e.golden {
                e.pos = spawnPoint()
            }
        }
    }

    private func bossAI(_ e: Enemy, toP: CGVector, d: Double, dt: Double) -> CGVector {
        e.timerA -= dt; e.timerB -= dt
        var v = CGVector(dx: toP.dx * e.speed, dy: toP.dy * e.speed)
        switch e.kind {
        case .bossSumo:
            if e.timerA <= 0 {
                e.timerA = 5
                telegraphStomp(at: e.pos, radius: 170) { [weak self, weak e] in
                    guard let self, let e, e.alive else { return }
                    if dist2(self.ppos, e.pos) < 170 * 170 { self.hurt(e.damage * 1.3) }
                    for _ in 0..<5 { self.spawn(.mini, at: self.jitter(e.pos, 60)) }
                }
                e.dashing = 1.0
            }
            if e.dashing > 0 { e.dashing -= dt; v = .zero }
        case .bossCowboy:
            if e.dashing > 0 {
                e.dashing -= dt
                v = CGVector(dx: e.dashDir.dx * 460, dy: e.dashDir.dy * 460)
            } else if e.timerA <= 0 {
                e.timerA = 4; e.dashing = 0.7; e.dashDir = toP
                Sound.tap.play()
            }
            if e.timerB <= 0 {
                e.timerB = 6
                for i in 0..<14 {
                    let a = Double(i) / 14 * 2 * .pi
                    fire(from: e.pos, dir: CGVector(dx: cos(a), dy: sin(a)), speed: 170, damage: 10)
                }
            }
        case .bossRoyal:
            v = CGVector(dx: v.dx * 0.8, dy: v.dy * 0.8)
            if e.timerA <= 0 {
                e.timerA = 5
                for i in 0..<6 {
                    let a = Double(i) / 6 * 2 * .pi
                    spawn(.spiky, at: CGPoint(x: e.pos.x + cos(a) * 90, y: e.pos.y + sin(a) * 90))
                }
            }
            if e.timerB <= 0 {
                e.timerB = 3.5
                for s in [-0.25, 0, 0.25] {
                    let a = atan2(toP.dy, toP.dx) + s
                    fire(from: e.pos, dir: CGVector(dx: cos(a), dy: sin(a)), speed: 230, damage: 11)
                }
            }
        case .bossBrain:
            // Mind Leech: a slow psychic spiral, and it blinks next to Nano with a shockwave.
            v = CGVector(dx: v.dx * 0.7, dy: v.dy * 0.7)
            e.timerC -= dt
            if e.timerC <= 0 {
                e.timerC = 0.22
                e.spin += 0.55
                for k in 0..<2 {
                    let a = e.spin + Double(k) * .pi
                    fire(from: e.pos, dir: CGVector(dx: cos(a), dy: sin(a)), speed: 140, damage: 8)
                }
            }
            if e.timerA <= 0 {
                e.timerA = 5
                let a = Double.random(in: 0..<(2 * .pi))
                let target = CGPoint(x: ppos.x + cos(a) * 190, y: ppos.y + sin(a) * 190)
                e.node.run(.fadeAlpha(to: 0.25, duration: 0.6))
                telegraphStomp(at: target, radius: 120) { [weak self, weak e] in
                    guard let self, let e, e.alive else { return }
                    e.pos = target; e.node.position = target; e.node.alpha = 1
                    if dist2(self.ppos, target) < 120 * 120 { self.hurt(e.damage) }
                    self.shooter = e; defer { self.shooter = nil }
                    self.ring(from: target, count: 12, speed: 180, damage: 10)
                }
            }
        case .bossMarrow:
            // Bone Colossus: volleys of bone spears, calls in blobs, and speeds up when hurt.
            if e.hp < e.maxHP * 0.5 { v = CGVector(dx: v.dx * 1.7, dy: v.dy * 1.7) }
            if e.timerA <= 0 {
                e.timerA = 4.5
                for w in 0..<3 {
                    run(.sequence([.wait(forDuration: 0.35 * Double(w)), .run { [weak self, weak e] in
                        guard let self, let e, e.alive, !self.simPaused else { return }
                        self.shooter = e; defer { self.shooter = nil }
                        self.ring(from: e.pos, count: 8, speed: 210, damage: 12, offset: Double(w) * .pi / 8)
                    }]))
                }
            }
            if e.timerB <= 0 {
                e.timerB = 7
                for _ in 0..<2 { spawn(.blob, at: jitter(e.pos, 80)) }
                for _ in 0..<4 { spawn(.mini, at: jitter(e.pos, 60)) }
            }
        case .bossVex:
            // King Vex: dashes, rings and summons; at half health he enrages and teleport-stomps.
            if e.phase == 0, e.hp < e.maxHP * 0.5 {
                e.phase = 1
                state.flash("KING VEX IS ENRAGED!", seconds: 2.5)
                shake = 0.6; Haptics.medium(); Sound.warning.play()
                e.baseTint = .red; e.baseBlend = 0.35; restoreTint(e)
            }
            let rage = e.phase == 1
            if e.dashing > 0 {
                e.dashing -= dt
                v = CGVector(dx: e.dashDir.dx * 480, dy: e.dashDir.dy * 480)
            }
            e.timerC -= dt
            if rage, e.timerC <= 0 {
                e.timerC = 0.16
                e.spin -= 0.45
                for k in 0..<3 {
                    let a = e.spin + Double(k) * 2 * .pi / 3
                    fire(from: e.pos, dir: CGVector(dx: cos(a), dy: sin(a)), speed: 150, damage: 8)
                }
            }
            if e.timerA <= 0 {
                e.timerA = rage ? 3 : 4
                if rage {
                    let target = CGPoint(x: ppos.x + CGFloat.random(in: -60...60), y: ppos.y + CGFloat.random(in: -60...60))
                    telegraphStomp(at: target, radius: 150) { [weak self, weak e] in
                        guard let self, let e, e.alive else { return }
                        e.pos = target; e.node.position = target
                        if dist2(self.ppos, target) < 150 * 150 { self.hurt(e.damage * 1.2) }
                        self.ring(from: target, count: 20, speed: 200, damage: 11)
                    }
                } else if Bool.random() {
                    e.dashing = 0.6; e.dashDir = toP
                } else {
                    ring(from: e.pos, count: 18, speed: 180, damage: 11)
                }
            }
            if e.timerB <= 0 {
                e.timerB = rage ? 6 : 8
                spawn(.elite, at: jitter(e.pos, 120))
                for i in 0..<6 {
                    let a = Double(i) / 6 * 2 * .pi
                    spawn(.spiky, at: CGPoint(x: e.pos.x + cos(a) * 100, y: e.pos.y + sin(a) * 100))
                }
            }
        default: break
        }
        return v
    }

    /// A ring of enemy shots.
    private func ring(from p: CGPoint, count: Int, speed: Double, damage: Double, offset: Double = 0) {
        for i in 0..<count {
            let a = offset + Double(i) / Double(count) * 2 * .pi
            fire(from: p, dir: CGVector(dx: cos(a), dy: sin(a)), speed: speed, damage: damage)
        }
    }

    private func telegraphStomp(at p: CGPoint, radius: Double, then: @escaping () -> Void) {
        let ring = SKShapeNode(circleOfRadius: CGFloat(radius))
        ring.position = p; ring.strokeColor = UIColor(red: 1, green: 0.3, blue: 0.35, alpha: 0.9); ring.lineWidth = 4
        ring.fillColor = UIColor(red: 1, green: 0.2, blue: 0.3, alpha: 0.12); ring.setScale(0.1)
        fxLayer.addChild(ring)
        ring.run(.sequence([.scale(to: 1, duration: 0.9), .run { [weak self] in
            then(); Sound.stomp.play(); Haptics.medium(); self?.shake = 0.35
        }, .group([.fadeOut(withDuration: 0.25), .scale(to: 1.15, duration: 0.25)]), .removeFromParent()]))
    }

    private func fire(from p: CGPoint, dir: CGVector, speed: Double, damage: Double, tint: UIColor? = nil) {
        let n = SKSpriteNode(texture: tex("slime")); n.size = CGSize(width: 18, height: 18); n.position = p
        var chill = false
        if let s = shooter, s.variant != .normal {
            n.color = s.baseTint; n.colorBlendFactor = 0.85
            chill = s.variant == .frost
        } else if let tint {
            n.color = tint; n.colorBlendFactor = 0.85
        }
        shotLayer.addChild(n)
        shots.append(Shot(pos: p, vel: CGVector(dx: dir.dx * speed, dy: dir.dy * speed), damage: damage * state.organ.difficulty, life: 4, node: n, chill: chill))
    }

    /// Shows the enemy's resting colors again (frozen enemies stay icy blue).
    private func restoreTint(_ e: Enemy) {
        if e.slowT > 0 {
            e.node.color = UIColor(red: 0.55, green: 0.85, blue: 1, alpha: 1); e.node.colorBlendFactor = 0.5
        } else {
            e.node.color = e.baseTint; e.node.colorBlendFactor = e.baseBlend
        }
    }

    /// Extra moves from the boss's variant: Frost ice rings, Toxic puddles, Inferno fire rings,
    /// Shadow invisibility, Mega backup.
    private func variantAbility(_ e: Enemy, dt: Double) {
        e.variantT -= dt
        switch e.variant {
        case .normal: break
        case .frost:
            if e.variantT <= 0 { e.variantT = 5; ring(from: e.pos, count: 10, speed: 130, damage: 7, offset: Double.random(in: 0..<1)) }
        case .toxic:
            if e.variantT <= 0 { e.variantT = 1.6; addPuddle(at: e.pos, radius: 62, life: 6) }
        case .inferno:
            if e.variantT <= 0 {
                e.variantT = 3.8
                for w in 0..<2 {
                    run(.sequence([.wait(forDuration: 0.3 * Double(w)), .run { [weak self, weak e] in
                        guard let self, let e, e.alive, !self.simPaused else { return }
                        self.shooter = e; defer { self.shooter = nil }
                        self.ring(from: e.pos, count: 16, speed: 165, damage: 9, offset: Double(w) * .pi / 16)
                    }]))
                }
            }
        case .shadow:
            if e.variantT <= 0 {
                e.cloaked.toggle()
                e.variantT = e.cloaked ? 2.5 : 5
                e.speed *= e.cloaked ? 1.4 : 1 / 1.4
                e.node.run(.fadeAlpha(to: e.cloaked ? 0.1 : 1, duration: 0.3))
                if e.cloaked { state.flash("THE SHADOW BOSS VANISHED!", seconds: 1.2) }
            }
        case .mega:
            if !e.summoned, e.hp < e.maxHP * 0.5 {
                e.summoned = true
                state.flash("MEGA BOSS CALLS FOR BACKUP!", seconds: 2)
                Sound.warning.play(); shake = 0.4
                for _ in 0..<2 { spawn(.elite, at: jitter(e.pos, 130)) }
            }
        }
    }

    private func bomberBlast(_ e: Enemy) {
        guard e.alive else { return }
        let p = e.pos, r = 80.0
        e.alive = false
        explosion(at: p, radius: r, color: UIColor(red: 1, green: 0.45, blue: 0.15, alpha: 1))
        Sound.bomb.play(volume: 0.5, minGap: 0.15)
        shake = max(shake, 0.25)
        if dist2(ppos, p) < pow(r + playerRadius, 2) { hurt(e.damage * 1.6) }
        // The blast hurts nearby viruses too: lure bombers into a crowd.
        each(near: p, radius: r + 30) { o in
            if o !== e, !o.kind.isBoss, dist2(o.pos, p) < pow(r + o.radius, 2) {
                self.damage(o, 30 * self.state.organ.difficulty, knock: norm(sub(o.pos, p)), kb: 220, quiet: true)
            }
        }
        e.node.removeAllActions()
        e.node.run(.sequence([.fadeOut(withDuration: 0.1), .removeFromParent()]))
    }

    private func healAround(_ e: Enemy) {
        let r = 160.0
        each(near: e.pos, radius: r) { o in
            guard o !== e, !o.golden, o.hp < o.maxHP, dist2(o.pos, e.pos) < r * r else { return }
            o.hp = min(o.maxHP, o.hp + o.maxHP * (o.kind.isBoss ? 0.03 : 0.3))
        }
        guard fxLayer.children.count < 140 else { return }
        let ring = SKShapeNode(circleOfRadius: CGFloat(r))
        ring.position = e.pos; ring.lineWidth = 3; ring.blendMode = .add; ring.zPosition = 2
        ring.strokeColor = UIColor(red: 0.4, green: 1, blue: 0.55, alpha: 0.8)
        ring.fillColor = UIColor(red: 0.4, green: 1, blue: 0.55, alpha: 0.08)
        ring.setScale(0.2)
        fxLayer.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 1, duration: 0.45), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
    }

    // MARK: weapons

    private func rebuildWeapons() {
        stats = PlayerStats.make(save: save, loadout: state.loadout)
        if rookie { stats.damage *= Rookie.damageBoost }
        let lo = state.loadout
        // swarm bots
        let want = lo.level(.swarm) > 0 ? WeaponStats.swarm(lo.level(.swarm)).bots : 0
        while bots.count < want {
            let n = SKSpriteNode(texture: tex(skin.botTexture)); n.size = CGSize(width: 26, height: 26); n.zPosition = 5
            world.addChild(n)
            bots.append(Bot(node: n, angle: Double(bots.count)))
        }
        for (i, b) in bots.enumerated() { b.angle = Double(i) / Double(max(1, bots.count)) * 2 * .pi }
        // shield orbs
        let orbs = lo.level(.shield) > 0 ? WeaponStats.shield(lo.level(.shield)).orbs : 0
        while shieldNodes.count < orbs {
            let n = SKSpriteNode(texture: tex("glow-pink")); n.size = CGSize(width: 36, height: 36); n.zPosition = 5
            let core = SKSpriteNode(texture: tex("orb-big")); core.size = CGSize(width: 20, height: 20); core.color = .magenta; core.colorBlendFactor = 0.6
            n.addChild(core)
            world.addChild(n); shieldNodes.append(n)
        }
        fieldNode.isHidden = lo.level(.field) == 0
        if lo.level(.field) > 0 {
            let r = WeaponStats.field(lo.level(.field)).radius
            fieldNode.path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil)
        }
        hp = min(hp, stats.maxHP)
    }

    private func weapons(_ dt: Double) {
        let lo = state.loadout
        let cd = stats.cooldown, dm = stats.damage
        // Pulse laser
        if lo.level(.laser) > 0 {
            laserT -= dt
            if laserT <= 0 {
                let w = WeaponStats.laser(lo.level(.laser))
                if let t = nearest(to: ppos, within: 420) {
                    laserT = w.cooldown * cd
                    let dir = norm(sub(t.pos, ppos))
                    for i in 0..<w.bolts {
                        let spread = (Double(i) - Double(w.bolts - 1) / 2) * 0.16
                        let a = atan2(dir.dy, dir.dx) + spread
                        let n = SKSpriteNode(texture: tex("bolt")); n.size = CGSize(width: 34, height: 14); n.zRotation = CGFloat(a)
                        if lo.level(.laser) >= evolvedLevel { n.color = UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1); n.colorBlendFactor = 0.8; n.size = CGSize(width: 46, height: 18) }
                        n.position = ppos; shotLayer.addChild(n)
                        bolts.append(Bolt(pos: ppos, vel: CGVector(dx: cos(a) * 560, dy: sin(a) * 560), damage: w.damage * dm, pierce: w.pierce, life: 0.9, node: n))
                    }
                    Sound.shoot.play(volume: 0.5, minGap: 0.08)
                } else { laserT = 0.1 }
            }
        }
        // Nano swarm
        if lo.level(.swarm) > 0 {
            let w = WeaponStats.swarm(lo.level(.swarm))
            for b in bots {
                b.angle += dt * 2.2
                let home = CGPoint(x: ppos.x + cos(b.angle) * 58, y: ppos.y + sin(b.angle) * 58)
                b.cooldown -= dt
                if let t = b.target, t.alive, !b.returning {
                    let dv = sub(t.pos, b.pos); let d = len(dv)
                    if d < t.radius + 10 {
                        damage(t, w.damage * dm, knock: norm(dv), kb: 60)
                        b.returning = true; b.cooldown = w.cooldown * cd
                    } else {
                        let s = min(d, 640 * dt)
                        b.pos.x += dv.dx / d * s; b.pos.y += dv.dy / d * s
                    }
                } else {
                    b.target = nil
                    let dv = sub(home, b.pos); let d = len(dv)
                    if d < 8 { b.returning = false; b.pos = home } else {
                        let s = min(d, 520 * dt); b.pos.x += dv.dx / d * s; b.pos.y += dv.dy / d * s
                    }
                    if !b.returning, b.cooldown <= 0, let t = nearest(to: ppos, within: 260) { b.target = t }
                }
                b.node.position = b.pos
            }
        }
        // Antibody shield
        if lo.level(.shield) > 0 {
            let w = WeaponStats.shield(lo.level(.shield))
            shieldAngle += dt * 3.2
            for (i, n) in shieldNodes.enumerated() {
                let a = shieldAngle + Double(i) / Double(shieldNodes.count) * 2 * .pi
                let p = CGPoint(x: ppos.x + cos(a) * w.radius, y: ppos.y + sin(a) * w.radius)
                n.position = p
                each(near: p, radius: 40) { e in
                    if e.shieldHitCD <= 0, dist2(e.pos, p) < pow(e.radius + 16, 2) {
                        e.shieldHitCD = 0.4
                        self.damage(e, w.damage * dm, knock: norm(sub(e.pos, self.ppos)), kb: 220)
                    }
                }
            }
        }
        // Shock field
        if lo.level(.field) > 0 {
            let w = WeaponStats.field(lo.level(.field))
            fieldNode.position = ppos
            fieldT -= dt
            if fieldT <= 0 {
                fieldT = 0.5 * cd
                fieldNode.run(.sequence([.fadeAlpha(to: 1, duration: 0.05), .fadeAlpha(to: 0.6, duration: 0.3)]))
                each(near: ppos, radius: w.radius + 30) { e in
                    if dist2(e.pos, self.ppos) < pow(w.radius + e.radius * 0.6, 2) { self.damage(e, w.damage * dm, knock: .zero, kb: 0, quiet: true) }
                }
            }
        }
        // Chain zap
        if lo.level(.zap) > 0 {
            zapT -= dt
            if zapT <= 0 {
                let w = WeaponStats.zap(lo.level(.zap))
                if var cur = nearest(to: ppos, within: 300) {
                    zapT = w.cooldown * cd
                    var hit: Set<ObjectIdentifier> = [ObjectIdentifier(cur)]
                    var points = [ppos, cur.pos]
                    damage(cur, w.damage * dm, knock: .zero, kb: 0)
                    for _ in 1..<w.jumps {
                        guard let nx = nearest(to: cur.pos, within: 170, excluding: hit) else { break }
                        hit.insert(ObjectIdentifier(nx)); points.append(nx.pos)
                        damage(nx, w.damage * dm, knock: .zero, kb: 0)
                        cur = nx
                    }
                    lightning(points)
                    Sound.zap.play(volume: 0.6, minGap: 0.2)
                } else { zapT = 0.2 }
            }
        }
        // Freeze ray: a frost wave that chills (slows) and damages nearby viruses
        if lo.level(.freeze) > 0 {
            freezeT -= dt
            if freezeT <= 0 {
                let w = WeaponStats.freeze(lo.level(.freeze))
                freezeT = w.cooldown * cd
                each(near: ppos, radius: w.radius + 30) { e in
                    if dist2(e.pos, self.ppos) < pow(w.radius + e.radius * 0.5, 2) {
                        e.slowT = 2; e.slowAmt = w.slow
                        self.damage(e, w.damage * dm, knock: .zero, kb: 0, quiet: true)
                    }
                }
                let ring = SKShapeNode(circleOfRadius: CGFloat(w.radius))
                ring.position = ppos; ring.zPosition = 3; ring.lineWidth = 5; ring.blendMode = .add
                ring.strokeColor = UIColor(red: 0.6, green: 0.9, blue: 1, alpha: 0.9)
                ring.fillColor = UIColor(red: 0.5, green: 0.85, blue: 1, alpha: 0.12)
                ring.setScale(0.3)
                world.addChild(ring)
                ring.run(.sequence([.group([.scale(to: 1, duration: 0.25), .sequence([.wait(forDuration: 0.1), .fadeOut(withDuration: 0.3)])]), .removeFromParent()]))
            }
        }
        // Homing missiles
        if lo.level(.missile) > 0 {
            missileT -= dt
            if missileT <= 0 {
                let w = WeaponStats.missile(lo.level(.missile))
                if nearest(to: ppos, within: 450) != nil {
                    missileT = w.cooldown * cd
                    for i in 0..<w.count {
                        let a = Double(i) / Double(w.count) * 2 * .pi + Double.random(in: 0...0.4)
                        let n = SKSpriteNode(texture: tex("bolt")); n.size = CGSize(width: 26, height: 12)
                        n.color = UIColor(red: 1, green: 0.55, blue: 0.2, alpha: 1); n.colorBlendFactor = 0.9
                        n.position = ppos; shotLayer.addChild(n)
                        bolts.append(Bolt(pos: ppos, vel: CGVector(dx: cos(a) * 260, dy: sin(a) * 260), damage: w.damage * dm, pierce: 0, life: 2.6, node: n, blast: w.blast))
                    }
                    Sound.shoot.play(volume: 0.4, minGap: 0.1)
                } else { missileT = 0.2 }
            }
        }
        // Cure bomb
        if lo.level(.bomb) > 0 {
            bombT -= dt
            if bombT <= 0 {
                let w = WeaponStats.bomb(lo.level(.bomb))
                bombT = w.cooldown * cd
                let n = SKSpriteNode(texture: tex("bomb")); n.size = CGSize(width: 30, height: 30); n.position = ppos
                n.run(.repeatForever(.sequence([.scale(to: 1.25, duration: 0.15), .scale(to: 1, duration: 0.15)])))
                shotLayer.addChild(n)
                bombs.append(Bomb(pos: ppos, fuse: 0.9, node: n))
            }
        }
    }

    private func lightning(_ pts: [CGPoint]) {
        guard pts.count > 1 else { return }
        let path = CGMutablePath()
        path.move(to: pts[0])
        for i in 1..<pts.count {
            let a = pts[i - 1], b = pts[i]
            for k in 1...4 {
                let t = CGFloat(k) / 4
                let j: CGFloat = k == 4 ? 0 : .random(in: -10...10)
                path.addLine(to: CGPoint(x: a.x + (b.x - a.x) * t + j, y: a.y + (b.y - a.y) * t + j))
            }
        }
        let s = SKShapeNode(path: path)
        s.strokeColor = UIColor(red: 0.75, green: 0.95, blue: 1, alpha: 1); s.lineWidth = 4; s.blendMode = .add
        fxLayer.addChild(s)
        s.run(.sequence([.fadeOut(withDuration: 0.18), .removeFromParent()]))
    }

    private func moveBolts(_ dt: Double) {
        for i in bolts.indices.reversed() {
            if bolts[i].blast > 0 {
                // Steer toward the nearest virus and speed up.
                if let t = nearest(to: bolts[i].pos, within: 360) {
                    let want = norm(sub(t.pos, bolts[i].pos))
                    let sp = min(620, len(bolts[i].vel) + 900 * dt)
                    let cur = norm(bolts[i].vel)
                    let k = min(1, 7 * dt)
                    let dir = norm(CGVector(dx: cur.dx + (want.dx - cur.dx) * k, dy: cur.dy + (want.dy - cur.dy) * k))
                    bolts[i].vel = CGVector(dx: dir.dx * sp, dy: dir.dy * sp)
                }
                bolts[i].node.zRotation = atan2(bolts[i].vel.dy, bolts[i].vel.dx)
            }
            bolts[i].pos.x += bolts[i].vel.dx * dt
            bolts[i].pos.y += bolts[i].vel.dy * dt
            bolts[i].life -= dt
            bolts[i].node.position = bolts[i].pos
            var dead = bolts[i].life <= 0
            if !dead {
                let p = bolts[i].pos
                var hitE: Enemy?
                each(near: p, radius: 70) { e in
                    if hitE == nil, !self.bolts[i].hit.contains(ObjectIdentifier(e)), dist2(e.pos, p) < pow(e.radius + 6, 2) { hitE = e }
                }
                if let e = hitE {
                    bolts[i].hit.insert(ObjectIdentifier(e))
                    damage(e, bolts[i].damage, knock: norm(bolts[i].vel), kb: 90)
                    if bolts[i].blast > 0 {
                        let r = bolts[i].blast, dmg = bolts[i].damage * 0.6
                        each(near: p, radius: r + 30) { o in
                            if o !== e, dist2(o.pos, p) < pow(r + o.radius, 2) { self.damage(o, dmg, knock: norm(sub(o.pos, p)), kb: 120, quiet: true) }
                        }
                        explosion(at: p, radius: r, color: UIColor(red: 1, green: 0.55, blue: 0.2, alpha: 1))
                    }
                    if bolts[i].pierce <= 0 { dead = true } else { bolts[i].pierce -= 1 }
                }
            }
            if dead { bolts[i].node.removeFromParent(); bolts.remove(at: i) }
        }
    }

    private func moveShots(_ dt: Double) {
        for i in shots.indices.reversed() {
            shots[i].pos.x += shots[i].vel.dx * dt
            shots[i].pos.y += shots[i].vel.dy * dt
            shots[i].life -= dt
            shots[i].node.position = shots[i].pos
            var dead = shots[i].life <= 0
            if !dead, dist2(shots[i].pos, ppos) < pow(playerRadius + 8, 2) {
                if shots[i].chill { chilled = 1.6 }
                hurt(shots[i].damage); dead = true
            }
            if dead { shots[i].node.removeFromParent(); shots.remove(at: i) }
        }
    }

    private func updateBombs(_ dt: Double) {
        let lo = state.loadout
        for i in bombs.indices.reversed() {
            bombs[i].fuse -= dt
            if bombs[i].fuse <= 0 {
                let w = WeaponStats.bomb(max(1, lo.level(.bomb)))
                let p = bombs[i].pos
                each(near: p, radius: w.radius + 30) { e in
                    if dist2(e.pos, p) < pow(w.radius + e.radius, 2) { self.damage(e, w.damage * self.stats.damage, knock: norm(sub(e.pos, p)), kb: 260) }
                }
                explosion(at: p, radius: w.radius, color: UIColor(red: 1, green: 0.4, blue: 0.85, alpha: 1))
                Sound.bomb.play(volume: 0.55, minGap: 0.15)
                bombs[i].node.removeFromParent(); bombs.remove(at: i)
            }
        }
    }

    private func explosion(at p: CGPoint, radius: Double, color: UIColor) {
        let g = SKSpriteNode(texture: tex("glow-pink")); g.position = p
        g.size = CGSize(width: radius * 2.2, height: radius * 2.2); g.setScale(0.3); g.alpha = 0.95
        g.blendMode = .add
        fxLayer.addChild(g)
        g.run(.sequence([.group([.scale(to: 1, duration: 0.22), .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
        let ring = SKShapeNode(circleOfRadius: CGFloat(radius)); ring.position = p; ring.strokeColor = color; ring.lineWidth = 6; ring.blendMode = .add; ring.setScale(0.4)
        fxLayer.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 1, duration: 0.25), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
    }

    // MARK: damage

    private func damage(_ e: Enemy, _ amount: Double, knock: CGVector, kb: Double, quiet: Bool = false) {
        guard e.alive else { return }
        let crit = Double.random(in: 0..<1) < 0.08
        let a = amount * (crit ? 2 : 1)
        e.hp -= a
        e.flash = 0.07
        e.node.color = .white
        if !e.kind.isBoss { let m = e.kind == .elite ? 0.3 : 1; e.knock.dx += knock.dx * kb * m; e.knock.dy += knock.dy * kb * m }
        popNumber(a, at: e.pos, crit: crit)
        if !quiet { Sound.hit.play(volume: 0.35, minGap: 0.05) }
        if e.hp <= 0 { kill(e) }
    }

    private func kill(_ e: Enemy) {
        e.alive = false
        e.aux?.removeFromParent(); e.aux = nil
        kills += 1
        burst(at: e.pos, kind: e.kind)
        Sound.kill.play(volume: 0.45, minGap: 0.06)
        // drops
        let xpValue = e.xp
        if e.golden {
            goldenKills += 1
            for _ in 0..<10 { drop(.coin(3), at: jitter(e.pos, 50)) }
            state.flash("GOLDEN VIRUS CAUGHT! +30 coins")
            Haptics.success()
        }
        if mutation == .splitters, !e.kind.isBoss, e.kind != .mini, e.kind != .blob, !e.golden {
            for _ in 0..<2 { spawn(.mini, at: jitter(e.pos, 14)) }
        }
        if e.kind.isBoss {
            bossKills += 1
            for _ in 0..<14 { drop(.coin(3), at: jitter(e.pos, 70)) }
            drop(.chest, at: e.pos)
            for _ in 0..<10 { drop(.xp(5), at: jitter(e.pos, 80)) }
            shake = 0.6
            Haptics.success()
            let otherBoss = enemies.first { $0.alive && $0.kind.isBoss && $0 !== e }
            if !state.organ.isEndless, let o = otherBoss { boss = o; state.flash("ONE DOWN, ONE TO GO!") }
            else if !state.organ.isEndless { bossDefeated = true; winSequence() } else { state.flash("BOSS DOWN! +\(14 * 3) coins") }
        } else if e.kind == .elite {
            drop(.chest, at: e.pos)
            drop(.xp(xpValue), at: e.pos)
        } else {
            drop(.xp(xpValue), at: e.pos)
            let r = Double.random(in: 0..<1)
            if r < 0.035 { drop(.coin(1), at: jitter(e.pos, 10)) } else if r < 0.042 { drop(.heart, at: jitter(e.pos, 10)) }
        }
        if e.kind == .blob {
            for _ in 0..<2 { spawn(.mini, at: jitter(e.pos, 16)) }
        }
        e.node.removeAllActions()
        e.node.run(.sequence([.group([.scale(to: 1.4, duration: 0.12), .fadeOut(withDuration: 0.12)]), .removeFromParent()]))
    }

    private func jitter(_ p: CGPoint, _ r: Double) -> CGPoint { let c = CGFloat(r); return CGPoint(x: p.x + CGFloat.random(in: -c...c), y: p.y + CGFloat.random(in: -c...c)) }

    private func burst(at p: CGPoint, kind: EnemyKind) {
        let color: UIColor
        switch kind {
        case .bossBrain: color = UIColor(red: 1, green: 0.55, blue: 0.8, alpha: 1)
        case .bossMarrow: color = UIColor(red: 0.95, green: 0.92, blue: 0.85, alpha: 1)
        case .bossVex: color = UIColor(red: 0.75, green: 0.3, blue: 1, alpha: 1)
        case .spiky, .bossCowboy: color = UIColor(red: 0.55, green: 1, blue: 0.3, alpha: 1)
        case .blob, .bossSumo: color = UIColor(red: 0.8, green: 0.5, blue: 1, alpha: 1)
        case .dart: color = UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 1)
        case .spitter: color = UIColor(red: 1, green: 0.95, blue: 0.3, alpha: 1)
        case .mini: color = UIColor(red: 1, green: 0.35, blue: 0.5, alpha: 1)
        case .elite, .bossRoyal: color = UIColor(red: 0.4, green: 0.9, blue: 1, alpha: 1)
        case .bomber: color = UIColor(red: 1, green: 0.45, blue: 0.15, alpha: 1)
        case .healer: color = UIColor(red: 0.4, green: 1, blue: 0.55, alpha: 1)
        case .sniper: color = UIColor(red: 1, green: 0.25, blue: 0.3, alpha: 1)
        case .spore: color = UIColor(red: 0.85, green: 0.75, blue: 1, alpha: 1)
        }
        // Skip sparks when the screen is already busy; a mass of kills would otherwise add hundreds of nodes.
        let busy = fxLayer.children.count > 140
        if busy && !kind.isBoss { return }
        let count = kind.isBoss ? 18 : 3
        for _ in 0..<count {
            let g = SKSpriteNode(texture: tex("glow")); g.color = color; g.colorBlendFactor = 1; g.blendMode = .add
            let s = CGFloat.random(in: 10...22) * (kind.isBoss ? 2.5 : 1)
            g.size = CGSize(width: s, height: s); g.position = p
            fxLayer.addChild(g)
            let a = Double.random(in: 0..<(2 * .pi)); let d = Double.random(in: 20...55) * (kind.isBoss ? 3 : 1)
            g.run(.sequence([.group([.moveBy(x: cos(a) * d, y: sin(a) * d, duration: 0.35), .fadeOut(withDuration: 0.35), .scale(to: 0.3, duration: 0.35)]), .removeFromParent()]))
        }
    }

    private func popNumber(_ v: Double, at p: CGPoint, crit: Bool) {
        let l: SKLabelNode
        if let r = labelPool.popLast() { l = r } else {
            l = SKLabelNode(fontNamed: "AvenirNext-Heavy"); l.zPosition = 20
        }
        guard fxLayer.children.count < 160 else { labelPool.append(l); return }
        l.removeAllActions(); l.alpha = 1; l.setScale(1)
        l.text = "\(Int(v.rounded()))"
        l.fontSize = crit ? 20 : 14
        l.fontColor = crit ? UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1) : .white
        l.position = CGPoint(x: p.x + CGFloat.random(in: -6...6), y: p.y + 14)
        fxLayer.addChild(l)
        l.run(.sequence([.group([.moveBy(x: 0, y: 26, duration: 0.5), .sequence([.wait(forDuration: 0.25), .fadeOut(withDuration: 0.25)])]),
                         .run { [weak self, weak l] in guard let l else { return }; l.removeFromParent(); self?.labelPool.append(l) }]))
    }

    private func hurt(_ amount: Double) {
        guard invuln <= 0, !over else { return }
        invuln = 0.6
        lastHit = time
        if !god { hp -= amount * (1 - stats.armor) }
        player.run(.sequence([.colorize(with: .red, colorBlendFactor: 0.8, duration: 0.05), .colorize(withColorBlendFactor: 0, duration: 0.25)]))
        player.texture = tex(skin.texture(.hurt))
        player.run(.sequence([.wait(forDuration: 0.4), .setTexture(tex(skin.texture(.fight)))]))
        shake = max(shake, 0.18)
        Sound.hurt.play(volume: 0.6, minGap: 0.2)
        Haptics.light()
        if hp <= 0 { die() }
    }

    private func contactDamage() {
        guard invuln <= 0 else { return }
        each(near: ppos, radius: 80) { e in
            if dist2(e.pos, self.ppos) < pow(e.radius + self.playerRadius - 4, 2) { self.hurt(e.damage) }
        }
    }

    // MARK: pickups & levels

    private func drop(_ kind: PickupKind, at p: CGPoint) {
        var name: String; var s: CGFloat
        switch kind {
        case .xp(let v): name = v >= 5 ? "orb-big" : "orb"; s = v >= 5 ? 22 : 15
        case .coin: name = "coin"; s = 20
        case .heart: name = "heart"; s = 24
        case .chest: name = "chest"; s = 40
        }
        var kind = kind
        if pickups.count > 320, case .xp(let add) = kind {
            // Too many orbs on the field: recycle the XP orb farthest from the player into this new drop,
            // so its value moves to where the fight is. (Merging into the oldest orb used to bury all new
            // DNA in orbs left far behind, which made long Endless runs stop leveling up.)
            var far = -1, farD = -1.0
            for i in pickups.indices where !pickups[i].pulled {
                if case .xp = pickups[i].kind { let d = dist2(pickups[i].pos, ppos); if d > farD { farD = d; far = i } }
            }
            if far >= 0, case .xp(let old) = pickups[far].kind {
                pickups[far].node.removeFromParent()
                pickups.remove(at: far)
                kind = .xp(old + add)
                name = "orb-big"; s = 22
            }
        }
        let n = SKSpriteNode(texture: tex(name)); n.size = CGSize(width: s, height: s); n.position = p
        if case .chest = kind { n.run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.4), .moveBy(x: 0, y: -4, duration: 0.4)]))) }
        pickupLayer.addChild(n)
        pickups.append(Pickup(kind: kind, pos: p, node: n))
    }

    private func updatePickups(_ dt: Double) {
        let mag = stats.magnet
        for i in pickups.indices.reversed() {
            let d2 = dist2(pickups[i].pos, ppos)
            if !pickups[i].pulled, d2 < mag * mag { pickups[i].pulled = true }
            if case .chest = pickups[i].kind, d2 < 140 * 140 { pickups[i].pulled = true }
            if pickups[i].pulled {
                let dv = sub(ppos, pickups[i].pos); let d = len(dv)
                let s = min(d, (340 + (mag - d) * 2) * dt)
                if d > 0 { pickups[i].pos.x += dv.dx / d * s; pickups[i].pos.y += dv.dy / d * s }
                pickups[i].node.position = pickups[i].pos
            }
            if dist2(pickups[i].pos, ppos) < 22 * 22 {
                collect(pickups[i].kind)
                pickups[i].node.removeFromParent()
                pickups.remove(at: i)
            }
        }
    }

    private func collect(_ k: PickupKind) {
        switch k {
        case .xp(let v):
            xp += v
            Sound.pickup.play(volume: 0.3, minGap: 0.045)
            while xp >= xpNeeded(level) { xp -= xpNeeded(level); level += 1; pendingLevels += 1 }
            if pendingLevels > 0 { showLevelUp(fromChest: false) }
        case .coin(let n):
            coinsCollected += n; Sound.coin.play(volume: 0.5, minGap: 0.05)
        case .heart:
            hp = min(stats.maxHP, hp + 30); Sound.coin.play(volume: 0.5)
            popLabel("+30", color: UIColor(red: 0.4, green: 1, blue: 0.55, alpha: 1))
        case .chest:
            chestsOpened += 1
            Haptics.success()
            showLevelUp(fromChest: true)
        }
    }

    private func popLabel(_ text: String, color: UIColor) {
        let l = SKLabelNode(fontNamed: "AvenirNext-Heavy"); l.text = text; l.fontSize = 18; l.fontColor = color
        l.position = CGPoint(x: ppos.x, y: ppos.y + 40); l.zPosition = 30
        fxLayer.addChild(l)
        l.run(.sequence([.group([.moveBy(x: 0, y: 30, duration: 0.7), .fadeOut(withDuration: 0.7)]), .removeFromParent()]))
    }

    private func xpNeeded(_ level: Int) -> Int { rookie ? Rookie.xpNeeded(level) : xpToNext(level) }

    private func showLevelUp(fromChest: Bool) {
        guard !simPaused, !over else { return }
        simPaused = true
        endTouch()
        var opts = state.loadout.rollOptions(rng: &rng)
        if rookie && !swarmFeatured { opts = Rookie.featureSwarm(opts, loadout: state.loadout); swarmFeatured = true }
        Sound.levelup.play()
        Haptics.medium()
        pushHUD()
        state.phase = .levelUp(opts, fromChest: fromChest)
    }

    private func choose(_ o: UpgradeOption) {
        switch o {
        case .heal: hp = stats.maxHP
        case .coins(let n): coinsCollected += n
        default: state.loadout.apply(o)
        }
        if case .weapon(let w, let l) = o, l >= evolvedLevel {
            state.flash("EVOLVED: \(w.evolvedTitle.uppercased())!", seconds: 2.5)
            Haptics.success()
        }
        rebuildWeapons()
        Sound.tap.play()
        if case .levelUp(_, fromChest: let chest) = state.phase, !chest { pendingLevels = max(0, pendingLevels - 1) }
        simPaused = false
        state.phase = .playing
        if pendingLevels > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.showLevelUp(fromChest: false) }
        }
        pushHUD()
    }

    // MARK: end of run

    private func die() {
        hp = 0
        simPaused = true
        endTouch()
        Sound.defeat.play()
        Haptics.error()
        player.texture = tex(skin.texture(.hurt))
        let canRevive = state.revivesUsed == 0
        pushHUD()
        state.phase = .dead(canRevive: canRevive)
    }

    private func revive() {
        guard !over, case .dead(canRevive: true) = state.phase else { return }
        state.revivesUsed += 1
        hp = stats.maxHP
        invuln = 2.5
        player.texture = tex(skin.texture(.fight))
        player.run(.repeat(.sequence([.fadeAlpha(to: 0.3, duration: 0.12), .fadeAlpha(to: 1, duration: 0.12)]), count: 9))
        // Clear the area around the player.
        each(near: ppos, radius: 260) { e in if !e.kind.isBoss { self.kill(e) } }
        explosion(at: ppos, radius: 260, color: UIColor(red: 0.45, green: 0.95, blue: 1, alpha: 1))
        simPaused = false
        state.phase = .playing
    }

    private func winSequence() {
        // Cure wave: every remaining virus pops.
        let wave = SKShapeNode(circleOfRadius: 40); wave.position = ppos; wave.strokeColor = UIColor(red: 0.5, green: 1, blue: 0.9, alpha: 1)
        wave.lineWidth = 10; wave.glowWidth = 12; fxLayer.addChild(wave)
        wave.run(.sequence([.group([.scale(to: 25, duration: 1.0), .fadeOut(withDuration: 1.0)]), .removeFromParent()]))
        run(.sequence([.wait(forDuration: 0.4), .run { [weak self] in
            guard let self else { return }
            for e in self.enemies where e.alive { self.kill(e) }
        }, .wait(forDuration: 1.6), .run { [weak self] in self?.finish(won: true) }]))
        state.flash("ORGAN CLEARED!", seconds: 2)
    }

    private func finish(won: Bool) {
        guard !over else { return }
        over = true
        if won { Sound.victory.play(); player.texture = tex(skin.texture(.joy)) }
        pushHUD()
        state.phase = .finished(won: won)
    }

    /// Debug/UI-test helper: start the run later in the timeline (e.g. right before the boss).
    func fastForward(to t: Double) {
        time = t
        let iv = eliteInterval
        nextElite = (floor(t / iv) + 1) * iv
    }

    /// Called by the HUD when the player gives up after dying.
    func giveUp() {
        switch state.phase {
        case .dead, .paused: finish(won: false)
        default: break
        }
    }

    var result: (coins: Int, kills: Int, time: Double, level: Int, bosses: Int, golden: Int) { (coinsCollected, kills, time, level, bossKills, goldenKills) }

    private var eliteInterval: Double { mutation.eliteInterval ?? state.organ.eliteInterval }

    // MARK: city mutations & events

    /// Golden Virus, supply drops and King Vex's ambush keep runs from feeling the same.
    private func events() {
        if time >= nextGolden {
            nextGolden = time + Double.random(in: 70...120)
            if boss == nil {
                let a = Double.random(in: 0..<(2 * .pi))
                let e = spawn(.spiky, at: CGPoint(x: ppos.x + cos(a) * 260, y: ppos.y + sin(a) * 260))
                e.golden = true; e.timerC = 15
                e.hp = 25 * state.organ.difficulty; e.node.alpha = 1
                e.baseTint = UIColor(red: 1, green: 0.82, blue: 0.2, alpha: 1); e.baseBlend = 0.75; restoreTint(e)
                e.node.run(.repeatForever(.sequence([.scale(to: 1.25, duration: 0.3), .scale(to: 1, duration: 0.3)])))
                state.flash("✨ A GOLDEN VIRUS! CATCH IT!", seconds: 2.5)
                Sound.coin.play()
            }
        }
        if time >= nextSupply {
            nextSupply = time + Double.random(in: 80...130)
            let a = Double.random(in: 0..<(2 * .pi))
            drop(.chest, at: CGPoint(x: ppos.x + cos(a) * 230, y: ppos.y + sin(a) * 230))
            state.flash("📦 SUPPLY DROP NEARBY!")
        }
        if !state.organ.isEndless, state.organ.infection >= 3, ambushEnds == nil, time >= ambushAt, boss == nil {
            ambushEnds = time + 20
            state.flash("👑 KING VEX AMBUSH! SURVIVE 20 SECONDS", seconds: 3)
            Sound.warning.play(); Haptics.medium(); shake = 0.4
            for i in 0..<14 {
                let a = Double(i) / 14 * 2 * .pi
                spawn(.dart, at: CGPoint(x: ppos.x + cos(a) * 320, y: ppos.y + sin(a) * 320))
            }
            spawn(.elite, at: CGPoint(x: ppos.x, y: ppos.y + 340))
        }
        if let end = ambushEnds, end > 0, time >= end {
            ambushEnds = -1
            coinsCollected += 40
            state.flash("AMBUSH SURVIVED! +40 coins")
            Haptics.success()
        }
    }

    /// Toxic Ground: puddles appear near Nano, arm after a short warning, and hurt while standing in them.
    private func updatePuddles(_ dt: Double) {
        if mutation == .toxic, !bossDefeated {
            nextPuddle -= dt
            if nextPuddle <= 0 {
                nextPuddle = 3.2
                addPuddle(at: CGPoint(x: ppos.x + CGFloat.random(in: -140...140), y: ppos.y + CGFloat.random(in: -140...140)), radius: 70, life: 7)
            }
        }
        for i in puddles.indices.reversed() {
            puddles[i].life -= dt
            if puddles[i].armed > 0 {
                puddles[i].armed -= dt
                if puddles[i].armed <= 0 { puddles[i].node.fillColor = UIColor(red: 0.45, green: 0.95, blue: 0.1, alpha: 0.35) }
            } else if !bossDefeated, dist2(puddles[i].pos, ppos) < pow(puddles[i].radius - 4, 2) {
                hurt(7 * (0.85 + 0.15 * state.organ.difficulty))
            }
            if puddles[i].life <= 0 {
                puddles[i].node.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
                puddles.remove(at: i)
            }
        }
    }

    private func addPuddle(at p: CGPoint, radius: Double, life: Double) {
        let n = SKShapeNode(circleOfRadius: CGFloat(radius))
        n.position = p; n.zPosition = 0.5; n.lineWidth = 3
        n.strokeColor = UIColor(red: 0.6, green: 1, blue: 0.2, alpha: 0.8)
        n.fillColor = UIColor(red: 0.45, green: 0.95, blue: 0.1, alpha: 0.12)
        n.setScale(0.2)
        n.run(.scale(to: 1, duration: 0.8))
        world.addChild(n)
        puddles.append(Puddle(pos: p, life: life, armed: 0.8, node: n, radius: radius))
    }

    /// Each organ has its own danger, so every stage plays differently:
    /// Lungs gusts of wind, Heart heartbeats that make viruses sprint, Stomach acid rain,
    /// Brain neuron beams, Bone Marrow bone spikes.
    private func updateHazards(_ dt: Double) {
        if windLeft > 0 { windLeft -= dt; if windLeft <= 0 { wind = .zero } }
        if rush > 0 { rush -= dt }
        guard !state.organ.isEndless, !bossDefeated else { return }
        nextHazard -= dt
        guard nextHazard <= 0 else { return }
        switch state.organ.id {
        case 1:
            nextHazard = 10
            let a = Double.random(in: 0..<(2 * .pi))
            let dir = CGVector(dx: cos(a), dy: sin(a))
            let arrows = ["→", "↗", "↑", "↖", "←", "↙", "↓", "↘"]
            let idx = Int(((a / (2 * .pi)) * 8).rounded()) % 8
            state.flash("💨 WIND GUST \(arrows[idx])", seconds: 1.5)
            run(.sequence([.wait(forDuration: 1), .run { [weak self] in
                self?.wind = CGVector(dx: dir.dx * 120, dy: dir.dy * 120); self?.windLeft = 2.5
            }]))
        case 2:
            nextHazard = 7
            rush = 1.1
            shake = max(shake, 0.25)
            Haptics.medium()
            let ring = SKShapeNode(circleOfRadius: 40)
            ring.position = ppos; ring.strokeColor = UIColor(red: 1, green: 0.25, blue: 0.35, alpha: 0.8); ring.lineWidth = 6; ring.zPosition = 6
            world.addChild(ring)
            ring.run(.sequence([.group([.scale(to: 9, duration: 0.6), .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
            Sound.stomp.play(volume: 0.5)
        case 3:
            nextHazard = 8
            for _ in 0..<4 {
                let p = CGPoint(x: ppos.x + CGFloat.random(in: -170...170), y: ppos.y + CGFloat.random(in: -170...170))
                telegraphStomp(at: p, radius: 60) { [weak self] in
                    guard let self else { return }
                    if dist2(self.ppos, p) < 60 * 60 { self.hurt(10 * (0.85 + 0.15 * self.state.organ.difficulty)) }
                }
            }
        case 4:
            nextHazard = 9
            let a = Double.random(in: 0..<(.pi))
            let dir = CGVector(dx: cos(a), dy: sin(a))
            let c = CGPoint(x: ppos.x + CGFloat.random(in: -60...60), y: ppos.y + CGFloat.random(in: -60...60))
            let L: CGFloat = 1400
            let path = CGMutablePath()
            path.move(to: CGPoint(x: c.x - dir.dx * L, y: c.y - dir.dy * L))
            path.addLine(to: CGPoint(x: c.x + dir.dx * L, y: c.y + dir.dy * L))
            let beam = SKShapeNode(path: path)
            beam.strokeColor = UIColor(red: 0.85, green: 0.4, blue: 1, alpha: 0.35); beam.lineWidth = 3; beam.zPosition = 6
            world.addChild(beam)
            beam.run(.sequence([.wait(forDuration: 1.0), .run { [weak self] in
                guard let self else { return }
                beam.strokeColor = UIColor(red: 1, green: 0.7, blue: 1, alpha: 0.95); beam.lineWidth = 22; beam.blendMode = .add
                // Distance from Nano to the beam line.
                let vx = Double(self.ppos.x - c.x), vy = Double(self.ppos.y - c.y)
                if abs(vx * Double(dir.dy) - vy * Double(dir.dx)) < 28 { self.hurt(14 * (0.85 + 0.15 * self.state.organ.difficulty)) }
                Sound.zap.play()
            }, .fadeOut(withDuration: 0.3), .removeFromParent()]))
        default:
            nextHazard = 7
            let ang = Double.random(in: 0..<(2 * .pi))
            let toward = CGVector(dx: cos(ang), dy: sin(ang))
            let start = CGPoint(x: ppos.x - toward.dx * 220, y: ppos.y - toward.dy * 220)
            for i in 0..<6 {
                let p = CGPoint(x: start.x + toward.dx * CGFloat(i) * 80, y: start.y + toward.dy * CGFloat(i) * 80)
                run(.sequence([.wait(forDuration: 0.12 * Double(i)), .run { [weak self] in
                    self?.telegraphStomp(at: p, radius: 50) { [weak self] in
                        guard let self else { return }
                        if dist2(self.ppos, p) < 50 * 50 { self.hurt(11 * (0.85 + 0.15 * self.state.organ.difficulty)) }
                    }
                }]))
            }
        }
    }

    private func pickObjective() {
        guard !state.organ.isEndless, !rookie else { return }
        objective = [.noHit, .kills, .fastBoss, .chests].randomElement()
        updateObjective()
    }

    /// Bonus objective: +60 coins when done.
    private func updateObjective() {
        guard let o = objective, !objectiveDone else { return }
        let text: String
        var done = false
        switch o {
        case .noHit:
            let clean = Int(time - lastHit)
            done = clean >= 45
            text = "Bonus: no damage for 45s (\(min(45, clean))s)"
        case .kills:
            done = kills >= 250 && time <= 180
            text = time > 180 && !done ? "Bonus failed: 250 kills by 3:00" : "Bonus: 250 kills by 3:00 (\(min(250, kills)))"
            if time > 180 && !done { state.objective = text; objective = nil; return }
        case .fastBoss:
            if let t0 = bossSpawnedAt, bossKills > 0 || bossDefeated { done = time - t0 <= 45 }
            if let t0 = bossSpawnedAt, time - t0 > 45, !done { state.objective = "Bonus failed: boss in 45s"; objective = nil; return }
            text = bossSpawnedAt.map { "Bonus: beat the boss in 45s (\(max(0, 45 - Int(time - $0)))s)" } ?? "Bonus: beat the boss within 45s"
        case .chests:
            done = chestsOpened >= 3
            text = "Bonus: open 3 chests (\(min(3, chestsOpened)))"
        }
        if state.objective != text { state.objective = text }
        if done {
            objectiveDone = true
            coinsCollected += 60
            state.objective = "Bonus complete! +60 coins"
            state.objectiveDone = true
            state.flash("🎯 BONUS COMPLETE! +60 coins")
            Haptics.success(); Sound.coin.play()
        }
    }

    /// Blackout: a dark overlay with a circle of light around Nano.
    private func setupDarkness() {
        guard mutation == .darkness else { return }
        let side = max(size.width, size.height) * 2.4
        let img = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512)).image { ctx in
            let colors = [UIColor(white: 0, alpha: 0).cgColor, UIColor(white: 0, alpha: 0.55).cgColor, UIColor(white: 0, alpha: 0.93).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.16, 0.3])!
            ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 256, y: 256), startRadius: 0, endCenter: CGPoint(x: 256, y: 256), endRadius: 256, options: .drawsAfterEndLocation)
        }
        let n = SKSpriteNode(texture: SKTexture(image: img), size: CGSize(width: side, height: side))
        n.zPosition = 50
        cam.addChild(n)
        darkness = n
    }

    // MARK: render & HUD

    private func compact() {
        if enemies.contains(where: { !$0.alive }) { enemies.removeAll { !$0.alive } }
    }

    private func render() {
        player.position = CGPoint(x: ppos.x, y: ppos.y + 4)
        playerShadow.position = CGPoint(x: ppos.x, y: ppos.y - 26)
        hpBar.position = CGPoint(x: ppos.x, y: ppos.y - 38)
        hpFill.size.width = 44 * CGFloat(max(0, hp / stats.maxHP))
        hpFill.color = hp / stats.maxHP < 0.3 ? UIColor(red: 1, green: 0.3, blue: 0.35, alpha: 1) : UIColor(red: 0.3, green: 0.95, blue: 0.55, alpha: 1)
        let ghosts = mutation == .ghosts
        for e in enemies where e.alive {
            e.node.position = e.pos
            if ghosts, !e.kind.isBoss, !e.golden {
                let d = sqrt(dist2(e.pos, ppos))
                e.node.alpha = CGFloat(d < 140 ? 1 : d > 260 ? 0.07 : 1 - (d - 140) / 120 * 0.93)
            }
            let ph = time + e.wobblePhase
            if e.kind == .dart {
                e.node.zRotation = CGFloat(ph * 2.4) // dash pop scale stays an action
            } else if !e.kind.isBoss {
                e.node.zRotation = e.wobbleAngle * CGFloat(sin(ph * .pi / 1.2))
                if e.kind == .bomber, e.phase == 1 { e.node.setScale(CGFloat(1.15 + 0.15 * sin(time * 40))) }
                else if e.kind != .mini { e.node.setScale(CGFloat(1.01 + 0.05 * sin(ph * .pi / 0.9))) }
            }
        }
        var cp = ppos
        if shake > 0 {
            shake -= 1.0 / 60
            let k = CGFloat(min(1, shake * 3)); cp.x += CGFloat.random(in: -6...6) * k; cp.y += CGFloat.random(in: -6...6) * k
        }
        cam.position = cp
        // background tiles follow the camera in a 3×3 grid
        let ox = floor(ppos.x / tile) * tile, oy = floor(ppos.y / tile) * tile
        var i = 0
        for dx in -1...1 { for dy in -1...1 {
            bgTiles[i].position = CGPoint(x: ox + (CGFloat(dx) + 0.5) * tile, y: oy + (CGFloat(dy) + 0.5) * tile)
            i += 1
        } }
    }

    private func pushHUD() {
        state.time = time
        state.level = level
        state.xpFraction = Double(xp) / Double(xpNeeded(level))
        state.hpFraction = max(0, hp / stats.maxHP)
        state.kills = kills
        state.coins = coinsCollected
        if let b = boss, b.alive { state.bossName = b.title; state.bossHP = max(0, b.hp / b.maxHP) } else { state.bossName = nil }
    }

    // MARK: autoplay (UI tests / screenshots)

    private func autoDirection() -> CGVector {
        var away = CGVector.zero
        each(near: ppos, radius: 180) { e in
            let dv = sub(self.ppos, e.pos); let d = max(10, len(dv))
            away.dx += dv.dx / d / d * 1400; away.dy += dv.dy / d / d * 1400
        }
        // drift in a slow circle so the screen keeps moving, and drift towards orbs
        let t = time * 0.35
        var v = CGVector(dx: cos(t) * 0.3 + away.dx, dy: sin(t) * 0.3 + away.dy)
        if let o = pickups.min(by: { dist2($0.pos, ppos) < dist2($1.pos, ppos) }), dist2(o.pos, ppos) < 700 * 700 {
            let danger = len(away) > 0.35
            let w: CGFloat = danger ? 0.25 : 1.2
            let dv = norm(sub(o.pos, ppos)); v.dx += dv.dx * w; v.dy += dv.dy * w
        }
        if let b = boss {
            let dv = sub(b.pos, ppos); let d = len(dv)
            if bossNear {
                // Screenshot mode: hover ~230 pt below the boss so both stay in frame.
                let want = d > 190 ? 1.0 : (d < 150 ? -1.0 : 0)
                return CGVector(dx: dv.dx / max(d, 1) * want + cos(time) * 0.2, dy: dv.dy / max(d, 1) * want)
            }
            if d > 260 { v.dx += dv.dx / d * 1.0; v.dy += dv.dy / d * 1.0 }
        }
        let l = len(v)
        return l > 1 ? CGVector(dx: v.dx / l, dy: v.dy / l) : v
    }
}
