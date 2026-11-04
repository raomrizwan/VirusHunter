import Foundation

// MARK: - Story mode
//
// King Vex, a virus mastermind, starts an outbreak in the player's country. Dr. Leuko (a white
// blood cell commander) sends Nano into Patient Zero of each of 10 main cities. Clearing all five
// organs makes a cure that saves that city and the outbreak jumps to the next one (each city is one Infection Level),
// until the whole country is virus free.
//
// Lines may use {city}, {next} and {country}; `Story.resolve` fills them in.

enum Speaker: String, CaseIterable {
    case nano, leuko, vex

    var name: String {
        switch self {
        case .nano: return "Nano"
        case .leuko: return "Dr. Leuko"
        case .vex: return "King Vex"
        }
    }
    /// Portrait image name (Nano's is swapped for the equipped skin by the view).
    var portrait: String {
        switch self {
        case .nano: return "nano-happy"
        case .leuko: return "dr-leuko"
        case .vex: return "king-vex"
        }
    }
    /// Villain talks from the right.
    var onRight: Bool { self == .vex }
}

struct StoryLine: Equatable {
    let speaker: Speaker
    let text: String
}

struct StoryScene: Identifiable, Equatable {
    let id: String
    let title: String
    let lines: [StoryLine]
}

private func L(_ s: Speaker, _ t: String) -> StoryLine { StoryLine(speaker: s, text: t) }

enum Story {
    /// Every scene, in story order (also the order of the Story journal).
    static let scenes: [StoryScene] = [
        StoryScene(id: "intro-1", title: "Chapter 1 · First Breath", lines: [
            L(.leuko, "Nano, systems online? Good. I'm Dr. Leuko, head of {country}'s immune defense."),
            L(.leuko, "A virus outbreak just hit {city}. Thousands of people are sick."),
            L(.leuko, "We found Patient Zero, the first person infected. Clean their organs and we can make a cure for the whole city."),
            L(.nano, "Beep! Ready to hunt."),
            L(.leuko, "Start with the lungs. Patient Zero can barely breathe. Clear them out!"),
        ]),
        StoryScene(id: "outro-1", title: "Lungs Cleared", lines: [
            L(.leuko, "Airways open! Patient Zero just took a deep breath, and the first cure doses are going out."),
            L(.vex, "Hmm. You flattened my Sumo. Impressive, for a tin can."),
            L(.nano, "Who are you?"),
            L(.vex, "I am King Vex. Every virus in {country} answers to me. This city is only the beginning."),
        ]),
        StoryScene(id: "intro-2", title: "Chapter 2 · Pulse", lines: [
            L(.leuko, "Vex is pushing infected cells into the bloodstream."),
            L(.leuko, "If the heart falls, the infection reaches everywhere."),
            L(.leuko, "Watch out for his Cowboy. It dashes fast and fires bullets in rings."),
        ]),
        StoryScene(id: "outro-2", title: "Heart Saved", lines: [
            L(.leuko, "Heartbeat is steady again! Nice flying, Nano."),
            L(.vex, "Steady? We'll see. My Royal Guard is waiting in the stomach acid."),
            L(.leuko, "Good news: our lab opened Endless training. Use it to get stronger between missions."),
        ]),
        StoryScene(id: "intro-3", title: "Chapter 3 · Acid Army", lines: [
            L(.leuko, "The stomach is Vex's fortress. His Royal Guard shields itself and calls in soldiers."),
            L(.nano, "Shields up. Lasers hot."),
        ]),
        StoryScene(id: "outro-3", title: "Fortress Fallen", lines: [
            L(.vex, "My guard... gone? Fine. I'll take what matters most."),
            L(.leuko, "He's heading for the brain! If he controls Patient Zero's mind, we lose everything."),
            L(.leuko, "Here, take the Golden plating. You've earned it."),
        ]),
        StoryScene(id: "intro-4", title: "Chapter 4 · Mind Games", lines: [
            L(.leuko, "Signal is weak in here... Nano, can you hear me?"),
            L(.vex, "Shhh. The doctor can't help you now. This mind is mine."),
            L(.nano, "Not for long."),
        ]),
        StoryScene(id: "outro-4", title: "Mind Freed", lines: [
            L(.leuko, "Signal's back! Patient Zero just opened their eyes!"),
            L(.vex, "Enough! I'll go to the source. The marrow makes new cells, and I'll make it make MINE."),
        ]),
        StoryScene(id: "intro-5", title: "Chapter 5 · The Source", lines: [
            L(.leuko, "Bone marrow. This is where new cells are born."),
            L(.leuko, "Vex is turning it into a virus factory. End this, Nano."),
        ]),
        StoryScene(id: "clear-1", title: "{city} Saved!", lines: [
            L(.leuko, "Patient Zero is clean! The cure is reaching every hospital in {city}. The city is saved!"),
            L(.vex, "You think you won? I don't die. I MUTATE."),
            L(.vex, "My stronger strain is already spreading in {next}. Catch me if you can."),
            L(.leuko, "He's moving city to city, getting stronger each time. Nano, to {next}!"),
        ]),
        StoryScene(id: "city-2", title: "Outbreak in {city}", lines: [
            L(.leuko, "Nano, {city} hospitals are full. A mutated strain is spreading fast."),
            L(.leuko, "Same organs, tougher viruses. Find Patient Zero, clear all five organs, and the cure will save the city."),
            L(.nano, "On my way!"),
        ]),
        StoryScene(id: "city-3", title: "Outbreak in {city}", lines: [
            L(.leuko, "Two cities saved! But Vex has reached {city}."),
            L(.vex, "Lucky shots. My new strain moves faster than you can think."),
        ]),
        StoryScene(id: "city-4", title: "Outbreak in {city}", lines: [
            L(.leuko, "The news is calling you a hero, Nano. {city} needs that hero now."),
            L(.vex, "Hero? Heroes get tired. Viruses don't."),
        ]),
        StoryScene(id: "city-5", title: "Outbreak in {city}", lines: [
            L(.leuko, "Halfway across {country}! Vex is getting desperate."),
            L(.leuko, "Spend your coins in the Tech Lab. Mutation Ranks keep upgrading Nano past MAX."),
            L(.vex, "Upgrade all you like. {city} is MY city now."),
        ]),
        StoryScene(id: "city-6", title: "Outbreak in {city}", lines: [
            L(.leuko, "Strange... the viruses in {city} are guarding something."),
            L(.nano, "A clue to where Vex hides?"),
            L(.leuko, "Maybe. Clear the city and we'll find out."),
        ]),
        StoryScene(id: "city-7", title: "Outbreak in {city}", lines: [
            L(.leuko, "We traced Vex's signal! Every city you save weakens his core."),
            L(.vex, "Stop that! ...I mean, it doesn't matter. Nothing matters."),
        ]),
        StoryScene(id: "city-8", title: "Outbreak in {city}", lines: [
            L(.vex, "You're still here? I've mutated eight times! EIGHT!"),
            L(.leuko, "And Nano has beaten you seven. Go get number eight, Nano."),
        ]),
        StoryScene(id: "city-9", title: "Outbreak in {city}", lines: [
            L(.leuko, "Vex's core is cracking. Only two cities left: {city} and then his last hideout."),
            L(.vex, "If I fall, I'll take {city} with me!"),
        ]),
        StoryScene(id: "city-10", title: "Final Outbreak · {city}", lines: [
            L(.leuko, "This is it. Vex's core is hiding in {city}. Every virus he has left is here."),
            L(.vex, "Come then, little robot. Let's finish this."),
            L(.nano, "Mission: save {country}. Engaging!"),
        ]),
        StoryScene(id: "finale", title: "{country} Is Virus Free!", lines: [
            L(.leuko, "All ten cities saved. Vex's core has collapsed."),
            L(.vex, "This... isn't... over..."),
            L(.leuko, "Millions of people are going home all over {country}. You did it, Nano."),
            L(.nano, "Beep boop! Mission complete."),
            L(.leuko, "Keep training in Endless. Somewhere out there, new viruses are always forming..."),
        ]),
        StoryScene(id: "endless", title: "Endless Training", lines: [
            L(.leuko, "This simulation is built from Vex's spores. It never ends."),
            L(.leuko, "Survive as long as you can. Every minute makes you stronger."),
        ]),
    ]

    static func scene(_ id: String) -> StoryScene? { scenes.first { $0.id == id } }

    /// Fills {city}, {next} and {country} for the given city (Infection Level).
    static func resolve(_ s: StoryScene, country: Country, city level: Int) -> StoryScene {
        func fill(_ t: String) -> String {
            t.replacingOccurrences(of: "{city}", with: country.city(level))
                .replacingOccurrences(of: "{next}", with: country.city(level + 1))
                .replacingOccurrences(of: "{country}", with: country.id == Country.world.id ? "the world" : country.name)
        }
        return StoryScene(id: s.id, title: fill(s.title), lines: s.lines.map { StoryLine(speaker: $0.speaker, text: fill($0.text)) })
    }

    /// Which city a scene's placeholders refer to, for replaying from the journal.
    static func city(for id: String) -> Int {
        if id == "finale" { return Organ.maxInfection }
        if id.hasPrefix("city-"), let n = Int(id.dropFirst(5)) { return n }
        return 1
    }

    /// Chapter name shown on the map card for an organ in the first city.
    static func chapter(_ organID: Int) -> String { scene("intro-\(organID)")?.title ?? "" }

    /// Shown before a run: the organ's chapter intro the first time (first city only), or Endless training.
    static func intro(for organ: Organ, save: SaveData) -> StoryScene? {
        let id = organ.isEndless ? "endless" : "intro-\(organ.id)"
        guard !save.seenStory.contains(id) else { return nil }
        if !organ.isEndless && (organ.infection > 1 || save.clearedInfection(organ.id) >= 1) { return nil }
        return scene(id).map { resolve($0, country: save.country, city: 1) }
    }

    /// Shown on the map: the arrival scene for the active city (from the second city on).
    static func mapScene(save: SaveData) -> StoryScene? {
        let c = save.currentCity
        guard c >= 2, save.citiesCleared < Organ.maxInfection, !save.seenStory.contains("city-\(c)"), let s = scene("city-\(c)") else { return nil }
        // Reveal this city's mutation only now, as a surprise.
        let m = CityMutation.forCity(c, country: save.country.id)
        let warning = StoryLine(speaker: .leuko, text: "Careful, Nano. Scans show a \(m.title) here: \(m.detail)")
        var extra = [warning]
        if let strain = VirusStrain.forCity(c, country: save.country.id) {
            extra.append(StoryLine(speaker: .nano, text: "The viruses here look different. Is that a new army?"))
            extra.append(StoryLine(speaker: .vex, text: "Meet my \(strain.title)! Bred just for this city."))
        }
        let r = resolve(s, country: save.country, city: c)
        return StoryScene(id: r.id, title: r.title, lines: r.lines + extra)
    }

    /// Shown after a won run: a saved city (first city / whole country), else the organ's first-clear outro.
    static func afterWin(_ organ: Organ, before: SaveData, after: SaveData) -> StoryScene? {
        guard !organ.isSideMode else { return nil }
        let country = after.country
        if after.citiesCleared > before.citiesCleared {
            if after.citiesCleared >= Organ.maxInfection, !after.seenStory.contains("finale"), let s = scene("finale") {
                return resolve(s, country: country, city: Organ.maxInfection)
            }
            if after.citiesCleared == 1, !after.seenStory.contains("clear-1"), let s = scene("clear-1") {
                return resolve(s, country: country, city: 1)
            }
        }
        let newlyCleared = before.clearedInfection(organ.id) < organ.infection && after.clearedInfection(organ.id) >= organ.infection
        let id = "outro-\(organ.id)"
        if organ.infection == 1, before.clearedInfection(organ.id) < 1, !after.seenStory.contains(id), var s = scene(id) {
            // A brand-new player skips the Lungs intro (they start straight in a run), so meet Dr. Leuko here.
            if organ.id == 1, !after.seenStory.contains("intro-1"), let intro = scene("intro-1") {
                s = StoryScene(id: s.id, title: s.title, lines: Array(intro.lines.prefix(2)) + s.lines)
            }
            s = StoryScene(id: s.id, title: s.title, lines: s.lines + [vaccineLine(organ.infection, after: after)])
            return resolve(s, country: country, city: 1)
        }
        guard newlyCleared else { return nil }
        return vaccineUpdate(organ, after: after)
    }

    /// Dr. Leuko's report after an organ is cleared: what it adds to the vaccine and how close the city is.
    static func vaccineUpdate(_ organ: Organ, after: SaveData) -> StoryScene {
        let level = organ.infection, n = Organ.all.count
        let done = after.organsCleared(inCity: level)
        var lines = [L(.leuko, organLine(organ.id, level))]
        let title: String
        if done >= n {
            title = "{city} Saved!"
            lines += [
                L(.leuko, "The vaccine is ready! Trucks are taking it to every hospital in {city}."),
                L(.nano, "Beep! Vaccine delivered."),
                L(.vex, level >= Organ.maxInfection - 1 ? "No... my last hideout is all I have left!" : "Enjoy it while it lasts. My next strain is already waking up in {next}."),
            ]
        } else {
            title = "Vaccine \(done)/\(n) · {city}"
            lines.append(vaccineLine(level, after: after))
        }
        return resolve(StoryScene(id: "vaccine-\(level)-\(organ.id)", title: title, lines: lines), country: after.country, city: level)
    }

    /// "Vaccine 2 of 5 ready" plus how many people in the city are getting better.
    static func vaccineLine(_ level: Int, after: SaveData) -> StoryLine {
        let n = Organ.all.count, done = after.organsCleared(inCity: level)
        let cured = Country.outbreakSize(level) - after.infected(inCity: level)
        if done >= n { return L(.leuko, "All five parts are done. The vaccine is ready for {city}!") }
        let left = n - done
        return L(.leuko, "Vaccine \(done) of \(n) ready! \(cured.formatted()) people in {city} are already getting better. \(left) more organ\(left == 1 ? "" : "s") to go.")
    }

    private static func organLine(_ id: Int, _ level: Int) -> String {
        let lines: [Int: [String]] = [
            1: ["Lung samples secured! Their antibodies are the first piece of the vaccine.",
                "The lungs are breathing clean air again. I'm adding their antibodies to the vaccine."],
            2: ["The heart's blood is clean. I can grow the vaccine in it now.",
                "Heartbeat steady! Clean blood cells are going straight into the vaccine lab."],
            3: ["Stomach acid is back to normal. Now the vaccine can work as a simple pill.",
                "The stomach is clear! Its healthy bacteria will make the vaccine stronger."],
            4: ["The brain is clear, and Patient Zero remembers where they caught the virus. A big clue for the vaccine!",
                "Brain signals are back to normal. I'm mapping how the virus fooled the body, so the vaccine can't be fooled."],
            5: ["Bone marrow is making healthy cells again. That's the strongest part of the vaccine.",
                "The marrow is ours! Fresh white blood cells are joining the vaccine."],
        ]
        let options = lines[id] ?? ["Organ cleared!"]
        return options[level % options.count]
    }

    /// Country health on the map, 0...1: every organ cleared in every city counts the same.
    static func recovery(_ save: SaveData) -> Double {
        let done = Organ.all.reduce(0) { $0 + min(Organ.maxInfection, save.clearedInfection($1.id)) }
        return Double(done) / Double(Organ.all.count * Organ.maxInfection)
    }
}
